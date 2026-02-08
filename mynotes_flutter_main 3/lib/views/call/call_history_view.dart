// Call history screen that pulls logged calls from the 'call_history'
// Firestore collection. Displays each call with contact name, time,
// duration, whether it was answered, and lets you tap to call back.
// Also maps phone numbers to names from the Contact Directories collection.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:flutter_application_1/utilities/apple_typography.dart';

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

  // Collection name for Contact Directories
  static const String _contactDirectoriesCollection = 'Contact Directories';

  String get _userId => AuthService.firebase().currentUser!.id;

  @override
  void initState() {
    super.initState();
    _fetchCallHistory();
  }

  // Loads all call records from 'call_history' for this user,
  // sorted newest-first, then resolves phone numbers to contact names.
  Future<void> _fetchCallHistory() async {
    try {
      setState(() {
        _isLoading = true;
      });

      QuerySnapshot querySnapshot = await _firestore
          .collection('call_history')
          .where('user_id', isEqualTo: _userId)
          .orderBy('timestamp', descending: true)
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
        color = answered ? Colors.green : Colors.red;
        break;
      case 'Outgoing':
        icon = Icons.call_made;
        color = Colors.green;
        break;
      case 'Missed':
        icon = Icons.call_missed;
        color = Colors.red;
        break;
      default:
        icon = Icons.call;
        color = Colors.grey;
    }

    return Icon(icon, color: color, size: 16);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Call History',
          style: AppleTypography.withAppleFont(
            AppleTypography.headline5.copyWith(
              fontWeight: FontWeight.normal,
            )
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.primary),
            onPressed: _fetchCallHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _callRecords.isEmpty
              ? Center(
                  child: Text(
                    'No call history found',
                    style: AppleTypography.withAppleFont(
                      AppleTypography.body1.copyWith(
                        color: Colors.grey,
                      )
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
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade300,
          ),
          child: const Icon(
            Icons.person,
            color: Colors.grey,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                display,
                style: AppleTypography.withAppleFont(
                  AppleTypography.body1.copyWith(
                    fontWeight: FontWeight.w600,
                  )
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatTime(call.timestamp),
              style: TextStyle(
                color: Colors.grey.shade600,
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
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.shade100,
            ),
            child: const Icon(
              Icons.call,
              color: Colors.green,
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

    return CallRecord(
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      duration: (map['duration'] as num).toDouble(),
      callType: map['call_type'] as String,
      answered: answered,
      address: map['address'] as String,
      rawCallType: map['raw_call_type'] as int,
      uploadedAt: (map['uploaded_at'] as Timestamp).toDate(),
    );
  }
}
