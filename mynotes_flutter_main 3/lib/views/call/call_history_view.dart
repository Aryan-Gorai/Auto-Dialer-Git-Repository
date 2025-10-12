import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class CallHistoryView extends StatefulWidget {
  const CallHistoryView({Key? key}) : super(key: key);

  @override
  State<CallHistoryView> createState() => _CallHistoryViewState();
}

class _CallHistoryViewState extends State<CallHistoryView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<CallRecord> _callRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCallHistory();
  }

  Future<void> _fetchCallHistory() async {
    try {
      setState(() {
        _isLoading = true;
      });

      QuerySnapshot querySnapshot = await _firestore
          .collection('call_history')
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

  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (!await launchUrl(launchUri)) {
      throw Exception('Could not launch $launchUri');
    }
  }

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
        title: const Text(
          'Call History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 34,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
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
                    style: TextStyle(fontSize: 16, color: Colors.grey),
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
                call.address,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
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
