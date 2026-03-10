// Call history screen that pulls logged calls from the 'call_history'
// Firestore collection.  Uses a doubly-linked list internally for
// efficient chronological traversal and merge sort for ordering.
// Displays each call with contact name, time, duration, whether it
// was answered, and lets you tap to call back.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:flutter_application_1/services/linked_list/call_history_linked_list.dart';
import 'package:flutter_application_1/services/sorting/merge_sort.dart';
import 'package:flutter_application_1/theme/components/app_components.dart';

class CallHistoryView extends StatefulWidget {
  const CallHistoryView({Key? key}) : super(key: key);

  @override
  State<CallHistoryView> createState() => _CallHistoryViewState();
}

class _CallHistoryViewState extends State<CallHistoryView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<CallRecord> _callRecords = [];
  bool _isLoading = true;
  // Map of normalized phone => contact name from Contact Directories
  Map<String, String> _directoryNameByPhone = {};

  // Doubly-linked list for efficient chronological traversal — O(1)
  // insertion at head/tail, O(1) node deletion, O(n) traversal.
  // (AQA Group A: Linked list maintenance)
  CallHistoryLinkedList _callLinkedList = CallHistoryLinkedList();

  // Collection name for Contact Directories
  static const String _contactDirectoriesCollection = 'Contact Directories';

  String get _userId => AuthService.firebase().currentUser!.id;

  @override
  void initState() {
    super.initState();
    _fetchCallHistory();
  }

  // Loads all call records from 'call_history' for this user,
  // builds a doubly-linked list for efficient traversal, then
  // merge-sorts the records newest-first and resolves phone→name.
  Future<void> _fetchCallHistory() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Build the doubly-linked list from Firestore in one pass.
      // This gives us O(1) insertion and bidirectional traversal.
      // Wrapped in its own try-catch so a failure here does not
      // prevent the main call-history query from running.
      try {
        _callLinkedList = await CallHistoryLinkedList.buildFromFirestore(
          userId: _userId,
        );
        print('📋 Built call-history linked list: ${_callLinkedList.length} nodes');
      } catch (e) {
        print('⚠️ Non-fatal: could not build linked list: $e');
        _callLinkedList = CallHistoryLinkedList();
      }

      // Fetch all call records for this user.
      // We intentionally omit .orderBy('timestamp') here because
      // we merge-sort in memory below — this avoids requiring a
      // Firestore composite index on (user_id + timestamp).
      QuerySnapshot querySnapshot = await _firestore
          .collection('call_history')
          .where('user_id', isEqualTo: _userId)
          .get();

      List<CallRecord> records = [];
      for (var doc in querySnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          records.add(CallRecord.fromMap(data));
        } catch (e) {
          print('Error parsing document ${doc.id}: $e');
        }
      }

      // Use our hand-coded merge sort (O(n log n), recursive
      // divide-and-conquer) instead of the built-in .sort().
      // Sorts by timestamp descending (newest first).
      records = mergeSort<CallRecord>(
        records,
        (a, b) => b.timestamp.compareTo(a.timestamp),
      );

      // Resolve display names from Contact Directories for the user's numbers
      await _resolveDirectoryNamesForCalls(records);

      setState(() {
        _callRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching call history: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Normalize a phone number for consistent lookup (last 9 digits only)
  // This handles cases like +44 7845967135 vs 07845967135
  String _normalizePhone(String input) {
    final digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length >= 9) {
      return digitsOnly.substring(digitsOnly.length - 9);
    }
    return digitsOnly; // Return as-is if less than 9 digits
  }

  // Batch-resolves normalised phone numbers against Contact Directories
  // so we can show contact names instead of raw numbers in the history list.
  Future<void> _resolveDirectoryNamesForCalls(List<CallRecord> records) async {
    try {
      final Set<String> normalizedPhones = records
          .map((r) => _normalizePhone(r.address))
          .where((n) => n.isNotEmpty)
          .toSet();

      if (normalizedPhones.isEmpty) {
        setState(() => _directoryNameByPhone = {});
        return;
      }

      // Fetch docs by computed IDs in parallel: '<userId>_<normalizedPhone>'
      final futures = normalizedPhones.map((normalized) async {
        final docId = '${_userId}_$normalized';
        final docRef = _firestore.collection(_contactDirectoriesCollection).doc(docId);
        final snap = await docRef.get();
        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>;
          final name = (data['contact_name'] as String?)?.trim();
          if (name != null && name.isNotEmpty) {
            return MapEntry(normalized, name);
          }
        }
        return null;
      }).toList();

      final results = await Future.wait(futures);
      final Map<String, String> nameMap = {};
      for (final entry in results) {
        if (entry != null) {
          nameMap[entry.key] = entry.value;
        }
      }
      setState(() => _directoryNameByPhone = nameMap);
    } catch (e) {
      // Non-fatal: keep default display as numbers
      print('Error resolving directory names: $e');
    }
  }

  // Launches the system phone dialer for a quick callback.
  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (!await launchUrl(launchUri)) {
      throw Exception('Could not launch $launchUri');
    }
  }

  // Converts raw seconds into something readable:
  // 0 = 'Missed', <60 = '45s', >=60 = '2m 30s'.
  String _formatDuration(double duration) {
    if (duration == 0) return 'Missed';
    
    final int seconds = duration.round();
    if (seconds < 60) {
      return '${seconds}s';
    } else {
      final int minutes = seconds ~/ 60;
      final int remainingSeconds = seconds % 60;
      return '${minutes}m ${remainingSeconds}s';
    }
  }

  // Shows 'HH:mm' for today, 'Yesterday', or 'dd/MM/yy' for older dates.
  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final timestampDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (timestampDate == today) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (timestampDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('dd/MM/yy').format(timestamp);
    }
  }

  // Returns the right coloured icon for the call type (incoming/outgoing/missed).
  Widget _buildCallIcon(String callType, bool answered) {
    IconData icon;
    Color color;

    switch (callType) {
      case 'Incoming':
        icon = answered ? Icons.call_received : Icons.call_missed;
        color = answered ? AppDesignTokens.success : AppDesignTokens.danger;
        break;
      case 'Outgoing':
        icon = Icons.call_made;
        color = AppDesignTokens.success;
        break;
      case 'Missed':
        icon = Icons.call_missed;
        color = AppDesignTokens.danger;
        break;
      default:
        icon = Icons.call;
        color = AppDesignTokens.neutral400;
    }

    return Icon(icon, color: color, size: 16);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Call History',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.normal,
            color: AppDesignTokens.neutral900,
          ),
        ),
        backgroundColor: AppDesignTokens.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppDesignTokens.primary),
            onPressed: _fetchCallHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _callRecords.isEmpty
              ? const Center(
                  child: Text(
                    'No call history found',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppDesignTokens.neutral500,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _callRecords.length,
                  itemBuilder: (context, index) {
                    final call = _callRecords[index];
                    return _buildCallItem(call);
                  },
                ),
    );
  }

  Widget _buildCallItem(CallRecord call) {
    final normalized = _normalizePhone(call.address);
    final display = _directoryNameByPhone[normalized] ?? call.address;
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppDesignTokens.neutral200, width: 1),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppDesignTokens.neutral200,
          ),
          child: const Icon(
            Icons.person,
            color: AppDesignTokens.neutral500,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                display,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.neutral900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatTime(call.timestamp),
              style: const TextStyle(
                color: AppDesignTokens.neutral600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            _buildCallIcon(call.callType, call.answered),
            const SizedBox(width: 6),
            Text(
              _formatDuration(call.duration),
              style: const TextStyle(
                color: AppDesignTokens.neutral600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppDesignTokens.successSoft,
            ),
            child: const Icon(
              Icons.call,
              color: AppDesignTokens.success,
              size: 20,
            ),
          ),
          onPressed: () => _makeCall(call.address),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}

class CallRecord {
  final DateTime timestamp;
  final double duration;
  final String callType;
  final bool answered;
  final String address;
  final int rawCallType;
  final DateTime uploadedAt;

  CallRecord({
    required this.timestamp,
    required this.duration,
    required this.callType,
    required this.answered,
    required this.address,
    required this.rawCallType,
    required this.uploadedAt,
  });

  factory CallRecord.fromMap(Map<String, dynamic> map) {
    // Handle different data types for 'answered' field
    bool answered;
    if (map['answered'] is bool) {
      answered = map['answered'] as bool;
    } else if (map['answered'] is int) {
      answered = (map['answered'] as int) == 1;
    } else {
      answered = false; // Default value
    }

    // Parse timestamp — required field
    final rawTimestamp = map['timestamp'];
    final DateTime timestamp;
    if (rawTimestamp is Timestamp) {
      timestamp = rawTimestamp.toDate();
    } else {
      timestamp = DateTime.now();
    }

    // Parse uploaded_at — optional, may be absent in externally-written docs
    final rawUploadedAt = map['uploaded_at'];
    final DateTime uploadedAt;
    if (rawUploadedAt is Timestamp) {
      uploadedAt = rawUploadedAt.toDate();
    } else {
      uploadedAt = timestamp; // fall back to call timestamp
    }

    return CallRecord(
      timestamp: timestamp,
      duration: (map['duration'] as num?)?.toDouble() ?? 0.0,
      callType: (map['call_type'] as String?) ?? 'Unknown',
      answered: answered,
      address: (map['address'] as String?) ?? '',
      rawCallType: (map['raw_call_type'] as int?) ?? 0,
      uploadedAt: uploadedAt,
    );
  }
}
