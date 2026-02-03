import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';

class CallCycleService {
  static const String listCyclesCollection = 'list_cycles';
  static const String listCycleEventsSubcollection = 'cycle_events';
  static const String callHistoryCollection = 'call_history';
  static const String listsCollection = 'lists_collection';

  static String get userId => AuthService.firebase().currentUser!.id;

  /// Normalize a phone number (last 9 digits) to align with Contact Directories.
  static String normalizePhone(String input) {
    final digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length >= 9) {
      return digitsOnly.substring(digitsOnly.length - 9);
    }
    return digitsOnly;
  }

  /// Start a new list call cycle and return the cycle document id.
  static Future<String> startCycle({
    required String listName,
    required int totalContacts,
    DateTime? startedAtClient,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final cycleRef = firestore.collection(listCyclesCollection).doc();
      final nowClient = startedAtClient ?? DateTime.now();

      print('📊 Creating cycle in collection: $listCyclesCollection');
      print('📊 User ID: $userId, List: $listName, Total contacts: $totalContacts');

      await cycleRef.set({
        'user_id': userId,
        'list_name': listName,
        'status': 'in_progress',
        'started_at_client': Timestamp.fromDate(nowClient),
        'started_at_server': FieldValue.serverTimestamp(),
        'ended_at': null,
        'total_contacts': totalContacts,
        'completed_contacts': 0,
        'completion_pct': 0.0,
        'total_call_duration_secs': 0,
        'stats': {
          'outgoing': 0,
          'missed': 0,
          'cancelled': 0,
        },
        'last_contact_index': -1,
        'last_reconciled_at': null,
      });

      print('✅ Cycle document created: ${cycleRef.id}');

      // Increment list-level counters (optional but normalized)
      final listQuery = await firestore
          .collection(listsCollection)
          .where('list_name', isEqualTo: listName)
          .where('user_id', isEqualTo: userId)
          .get();

      if (listQuery.docs.isNotEmpty) {
        await listQuery.docs.first.reference.update({
          'cycle_initiated_count': FieldValue.increment(1),
          'last_cycle_started_at': FieldValue.serverTimestamp(),
        });
      }

      return cycleRef.id;
    } catch (e) {
      print('❌ Error starting cycle: $e');
      rethrow;
    }
  }

  /// Record that the call dialog was shown (intent created).
  static Future<String> recordCallDialogShown({
    required String cycleId,
    required String listName,
    required String contactDocId,
    required String contactName,
    required String contactPhoneNumber,
    required int contactIndex,
    DateTime? dialogShownAt,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final eventRef = firestore
        .collection(listCyclesCollection)
        .doc(cycleId)
        .collection(listCycleEventsSubcollection)
        .doc();

    await eventRef.set({
      'user_id': userId,
      'list_name': listName,
      'cycle_id': cycleId,
      'contact_doc_id': contactDocId,
      'contact_name': contactName,
      'contact_phone_number': contactPhoneNumber,
      'normalized_phone': normalizePhone(contactPhoneNumber),
      'contact_index': contactIndex,
      'dialog_shown_at_client': Timestamp.fromDate(dialogShownAt ?? DateTime.now()),
      'dial_pressed_at_client': null,
      'cancelled_at_client': null,
      'action': 'shown', // shown | dialed | cancelled
      'linked_call_history_id': null,
      'matched_at': null,
      'match_score': null,
    });

    return eventRef.id;
  }

  /// Mark that the user pressed "Dial" for an existing intent.
  static Future<void> recordDialPressed({
    required String cycleId,
    required String eventId,
    required int contactIndex,
    DateTime? dialPressedAt,
  }) async {
    final firestore = FirebaseFirestore.instance;
    await firestore
        .collection(listCyclesCollection)
        .doc(cycleId)
        .collection(listCycleEventsSubcollection)
        .doc(eventId)
        .update({
      'dial_pressed_at_client': Timestamp.fromDate(dialPressedAt ?? DateTime.now()),
      'action': 'dialed',
    });

    await firestore.collection(listCyclesCollection).doc(cycleId).update({
      'last_contact_index': contactIndex,
    });
  }

  /// Mark that the user cancelled the dialog for an existing intent.
  static Future<void> recordDialCancelled({
    required String cycleId,
    required String eventId,
    DateTime? cancelledAt,
  }) async {
    final firestore = FirebaseFirestore.instance;
    await firestore
        .collection(listCyclesCollection)
        .doc(cycleId)
        .collection(listCycleEventsSubcollection)
        .doc(eventId)
        .update({
      'cancelled_at_client': Timestamp.fromDate(cancelledAt ?? DateTime.now()),
      'action': 'cancelled',
    });

    await firestore.collection(listCyclesCollection).doc(cycleId).update({
      'stats.cancelled': FieldValue.increment(1),
    });
  }

  /// End a call cycle and compute completion.
  static Future<void> endCycle({
    required String cycleId,
    required int completedContacts,
    required int totalContacts,
    DateTime? endedAt,
  }) async {
    final completionPct = totalContacts == 0
        ? 0.0
        : (completedContacts / totalContacts).clamp(0.0, 1.0);

    await FirebaseFirestore.instance
        .collection(listCyclesCollection)
        .doc(cycleId)
        .update({
      'ended_at': Timestamp.fromDate(endedAt ?? DateTime.now()),
      'status': 'ended',
      'completed_contacts': completedContacts,
      'total_contacts': totalContacts,
      'completion_pct': completionPct,
    });
  }

  /// Reconcile call intents with delayed call history records.
  /// This is NOT time-bound; it uses matching scores based on phone, time,
  /// and order to merge later-arriving macOS call history.
  static Future<void> reconcileCycle({
    required String cycleId,
  }) async {
    final firestore = FirebaseFirestore.instance;

    final cycleRef = firestore.collection(listCyclesCollection).doc(cycleId);
    final cycleSnap = await cycleRef.get();
    if (!cycleSnap.exists) return;

    final cycleData = cycleSnap.data()!;
    final listName = cycleData['list_name'] as String?;
    if (listName == null) return;

    // Load intents that are dialed and not yet matched.
    final intentsSnap = await cycleRef
        .collection(listCycleEventsSubcollection)
        .where('action', isEqualTo: 'dialed')
        .get();

    final intents = intentsSnap.docs
        .where((d) => d.data()['linked_call_history_id'] == null)
        .toList();

    if (intents.isEmpty) {
      await cycleRef.update({'last_reconciled_at': FieldValue.serverTimestamp()});
      return;
    }

    // Load call history records not yet linked for this user.
    final historySnap = await firestore
        .collection(callHistoryCollection)
        .where('user_id', isEqualTo: userId)
        .get();

    final history = historySnap.docs
        .where((d) => d.data()['linked_intent_id'] == null)
        .toList();

    if (history.isEmpty) {
      await cycleRef.update({'last_reconciled_at': FieldValue.serverTimestamp()});
      return;
    }

    final historySorted = history.toList()
      ..sort((a, b) {
        final ta = (a.data()['timestamp'] as Timestamp?)?.toDate();
        final tb = (b.data()['timestamp'] as Timestamp?)?.toDate();
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return ta.compareTo(tb);
      });

    final usedHistoryIds = <String>{};

    for (final intent in intents) {
      final intentData = intent.data();
      final intentPhone = intentData['normalized_phone'] as String? ?? '';
      final intentDialedAt = (intentData['dial_pressed_at_client'] as Timestamp?)?.toDate();
      final intentIndex = intentData['contact_index'] as int? ?? 0;

      double bestScore = 0.0;
      DocumentSnapshot<Map<String, dynamic>>? bestHistory;

      for (int i = 0; i < historySorted.length; i++) {
        final hist = historySorted[i];
        if (usedHistoryIds.contains(hist.id)) continue;

        final histData = hist.data();
        final histAddress = histData['address']?.toString() ?? '';
        final histPhone = normalizePhone(histAddress);
        if (histPhone != intentPhone) continue;

        final histTimestamp = (histData['timestamp'] as Timestamp?)?.toDate();
        final timeScore = _timeScore(intentDialedAt, histTimestamp);
        final orderScore = _orderScore(intentIndex, i);
        final directionScore = _directionScore(histData['call_type']?.toString());

        // Phone match is hard requirement; score aggregates soft signals.
        final score = (0.65 * 1.0) + (0.20 * timeScore) + (0.10 * orderScore) + (0.05 * directionScore);

        if (score > bestScore) {
          bestScore = score;
          bestHistory = hist;
        }
      }

      if (bestHistory != null && bestScore >= 0.55) {
        usedHistoryIds.add(bestHistory.id);

        await intent.reference.update({
          'linked_call_history_id': bestHistory.id,
          'matched_at': FieldValue.serverTimestamp(),
          'match_score': bestScore,
        });

        await bestHistory.reference.update({
          'linked_intent_id': intent.id,
          'linked_cycle_id': cycleId,
          'linked_list_name': listName,
        });
      }
    }

    await _recomputeCycleAggregates(cycleRef);
  }

  static double _timeScore(DateTime? intentTime, DateTime? actualTime) {
    if (intentTime == null || actualTime == null) return 0.0;
    final diffSecs = (actualTime.difference(intentTime).inSeconds).abs();
    // Non time-bound decay: 1 / (1 + minutes difference)
    final diffMins = diffSecs / 60.0;
    return 1.0 / (1.0 + diffMins);
  }

  static double _orderScore(int intentIndex, int historyIndex) {
    final diff = (intentIndex - historyIndex).abs();
    return 1.0 / (1.0 + diff.toDouble());
  }

  static double _directionScore(String? callType) {
    if (callType == null) return 0.0;
    final normalized = callType.toLowerCase();
    if (normalized.contains('outgoing')) return 1.0;
    if (normalized.contains('unanswered')) return 0.6;
    if (normalized.contains('missed')) return 0.4;
    return 0.2; // Incoming or unknown
  }

  static Future<void> _recomputeCycleAggregates(
      DocumentReference<Map<String, dynamic>> cycleRef) async {
    final events = await cycleRef.collection(listCycleEventsSubcollection).get();

    int totalDuration = 0;
    int outgoing = 0;
    int missed = 0;
    int cancelled = 0;

    for (final e in events.docs) {
      final data = e.data();
      final action = data['action'] as String?;
      if (action == 'cancelled') {
        cancelled++;
        continue;
      }

      final linkedHistoryId = data['linked_call_history_id'] as String?;
      if (linkedHistoryId == null) continue;

      final histSnap = await FirebaseFirestore.instance
          .collection(callHistoryCollection)
          .doc(linkedHistoryId)
          .get();
      if (!histSnap.exists) continue;

      final histData = histSnap.data()!;
      final duration = (histData['duration'] as num?)?.toInt() ?? 0;
      final callType = histData['call_type']?.toString().toLowerCase() ?? '';

      totalDuration += max(0, duration);

      if (callType.contains('outgoing')) outgoing++;
      if (callType.contains('missed')) missed++;
    }

    await cycleRef.update({
      'total_call_duration_secs': totalDuration,
      'stats.outgoing': outgoing,
      'stats.missed': missed,
      'stats.cancelled': cancelled,
      'last_reconciled_at': FieldValue.serverTimestamp(),
    });
  }
}
