// List performance chart — visualises how each call cycle performed
// for a specific list. Shows contacts called, answered, and completion
// rate per cycle, using data from the call_cycles Firestore collection.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:flutter_application_1/utilities/apple_typography.dart';
import 'package:intl/intl.dart';

class ListPerformanceChart extends StatefulWidget {
  final String? selectedList;
  final String? targetUserId;
  
  const ListPerformanceChart({Key? key, this.selectedList, this.targetUserId}) : super(key: key);

  @override
  State<ListPerformanceChart> createState() => _ListPerformanceChartState();
}

class _ListPerformanceChartState extends State<ListPerformanceChart> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String? _selectedList;
  List<String> _availableLists = [];
  List<CycleData> _cyclesData = [];

  String get _userId => widget.targetUserId ?? AuthService.firebase().currentUser!.id;

  @override
  void initState() {
    super.initState();
    _selectedList = widget.selectedList;
    _loadLists();
  }

  @override
  void didUpdateWidget(ListPerformanceChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedList != widget.selectedList) {
      _selectedList = widget.selectedList;
      if (_selectedList != null && _selectedList!.isNotEmpty) {
        _fetchCycleData();
      }
    }
  }

  // Loads the user's available lists from Firestore and auto-selects
  // the first one (or the list passed in via widget.selectedList).
  Future<void> _loadLists() async {
    try {
      final snapshot = await _firestore
          .collection('lists_collection')
          .where('user_id', isEqualTo: _userId)
          .get();

      List<String> lists = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final listName = data['list_name'] as String?;
        if (listName != null && listName.isNotEmpty) {
          lists.add(listName);
        }
      }

      lists.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (mounted) {
        setState(() {
          _availableLists = lists;
          if (_selectedList == null && lists.isNotEmpty) {
            _selectedList = lists.first;
            _fetchCycleData();
          } else if (_selectedList != null) {
            _fetchCycleData();
          } else {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      print('Error loading lists: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Fetches all call cycles for the selected list, then computes
  // per-cycle stats (calls made, duration, answer rate) for display.
  Future<void> _fetchCycleData() async {
    if (_selectedList == null || _selectedList!.isEmpty) {
      setState(() {
        _cyclesData = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('📊 Fetching cycles for list: $_selectedList');

      // Fetch all cycles for this list
      final cyclesSnapshot = await _firestore
          .collection('list_cycles')
          .where('user_id', isEqualTo: _userId)
          .where('list_name', isEqualTo: _selectedList)
          .orderBy('started_at_server', descending: true)
          .get();

      print('📂 Found ${cyclesSnapshot.docs.length} cycles');

      List<CycleData> cycles = [];
      int cycleNumber = cyclesSnapshot.docs.length;

      for (var cycleDoc in cyclesSnapshot.docs) {
        final cycleData = cycleDoc.data();
        final cycleId = cycleDoc.id;

        // Get cycle basic info
        final startedAtClient = cycleData['started_at_client'] as Timestamp?;
        final startedAtServer = cycleData['started_at_server'] as Timestamp?;
        final endedAt = cycleData['ended_at'] as Timestamp?;
        final stats = cycleData['stats'] as Map<String, dynamic>?;
        final totalContacts = cycleData['total_contacts'] as int? ?? 0;
        final completedContacts = cycleData['completed_contacts'] as int? ?? 0;

        final startTime = startedAtClient?.toDate() ?? startedAtServer?.toDate();
        final endTime = endedAt?.toDate();

        // Calculate completion percentage
        double completionPct = 0;
        if (totalContacts > 0) {
          completionPct = (completedContacts / totalContacts) * 100;
        }

        // Calculate total duration
        Duration? totalDuration;
        if (startTime != null && endTime != null) {
          totalDuration = endTime.difference(startTime);
        }

        // Fetch cycle_events for this cycle
        final eventsSnapshot = await _firestore
            .collection('list_cycles')
            .doc(cycleId)
            .collection('cycle_events')
            .orderBy('dial_pressed_at_client', descending: false)
            .get();

        // Fetch call_history for duration data
        final callHistorySnapshot = await _firestore
            .collection('call_history')
            .where('user_id', isEqualTo: _userId)
            .get();

        // Create a map of normalized phone -> duration for quick lookup
        Map<String, Map<DateTime, double>> callDurationMap = {};
        for (var historyDoc in callHistorySnapshot.docs) {
          final historyData = historyDoc.data();
          final address = historyData['address'] as String? ?? '';
          final duration = (historyData['duration'] as num?)?.toDouble() ?? 0.0;
          final timestamp = historyData['timestamp'] as Timestamp?;
          
          if (address.isNotEmpty && timestamp != null) {
            final normalizedPhone = _normalizePhone(address);
            if (!callDurationMap.containsKey(normalizedPhone)) {
              callDurationMap[normalizedPhone] = {};
            }
            callDurationMap[normalizedPhone]![timestamp.toDate()] = duration;
          }
        }

        List<CallEventData> callEvents = [];
        for (var eventDoc in eventsSnapshot.docs) {
          final eventData = eventDoc.data();
          
          final contactName = eventData['contact_name'] as String? ?? 'Unknown';
          final contactPhone = eventData['contact_phone_number'] as String? ?? '';
          final dialPressed = eventData['dial_pressed_at_client'] as Timestamp?;
          final action = eventData['action'] as String? ?? '';
          
          // Check if call was answered by looking for matched_at timestamp
          final matchedAt = eventData['matched_at'] as Timestamp?;
          bool wasAnswered = matchedAt != null;

          // Get duration from call_history by matching phone and timestamp
          double? callDuration;
          if (contactPhone.isNotEmpty && dialPressed != null) {
            final normalizedPhone = _normalizePhone(contactPhone);
            final callTime = dialPressed.toDate();
            
            // Try to find exact match or close match (within 30 seconds)
            if (callDurationMap.containsKey(normalizedPhone)) {
              final phoneDurations = callDurationMap[normalizedPhone]!;
              callDuration = phoneDurations[callTime];
              
              // If no exact match, try to find within 30 seconds
              if (callDuration == null) {
                for (var entry in phoneDurations.entries) {
                  if ((entry.key.difference(callTime).inSeconds.abs() <= 30)) {
                    callDuration = entry.value;
                    break;
                  }
                }
              }
            }
          }

          if (action == 'dialed' && dialPressed != null) {
            callEvents.add(CallEventData(
              contactName: contactName,
              contactPhone: contactPhone,
              timestamp: dialPressed.toDate(),
              wasAnswered: wasAnswered,
              durationSeconds: callDuration,
            ));
          }
        }

        cycles.add(CycleData(
          cycleNumber: cycleNumber,
          cycleId: cycleId,
          dateStarted: startTime,
          dateEnded: endTime,
          completionPercentage: completionPct,
          totalDuration: totalDuration,
          totalContacts: totalContacts,
          completedContacts: completedContacts,
          outgoingCalls: stats?['outgoing'] as int? ?? 0,
          callEvents: callEvents,
        ));

        cycleNumber--;
      }

      if (mounted) {
        setState(() {
          _cyclesData = cycles;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error fetching cycle data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  // Strips non-digits and keeps the last 9 for phone number matching.
  String _normalizePhone(String input) {
    final digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length >= 9) {
      return digitsOnly.substring(digitsOnly.length - 9);
    }
    return digitsOnly;
  }
  // Turns a Duration into a human-readable string (e.g. '2h 15m 30s').
  String _formatDuration(Duration? duration) {
    if (duration == null) return 'N/A';
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'List Performance',
            style: AppleTypography.withAppleFont(
              AppleTypography.headline5.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'View detailed cycle statistics for each list',
            style: AppleTypography.withAppleFont(
              AppleTypography.body2.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // List selector dropdown
          Row(
            children: [
              Text(
                'Choose List:',
                style: AppleTypography.withAppleFont(
                  AppleTypography.body1.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _availableLists.isEmpty
                    ? const Text('No lists found')
                    : DropdownButton<String>(
                        isExpanded: true,
                        value: _availableLists.contains(_selectedList) ? _selectedList : null,
                        hint: const Text('Select a list'),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedList = newValue;
                            _fetchCycleData();
                          });
                        },
                        items: _availableLists.map((listName) {
                          return DropdownMenuItem<String>(
                            value: listName,
                            child: Text(listName),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Content
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_selectedList == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Text(
                  'Please select a list to view cycle data',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            )
          else if (_cyclesData.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Text(
                  'No cycles found for "$_selectedList"',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            )
          else
            // Cycle data table
            Column(
              children: _cyclesData.map((cycle) => _buildCycleRow(cycle)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildCycleRow(CycleData cycle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with cycle number
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Cycle ${cycle.cycleNumber}',
                  style: AppleTypography.withAppleFont(
                    AppleTypography.subtitle1.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Cycle info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Date Started', 
                  cycle.dateStarted != null 
                    ? DateFormat('MMM d, yyyy h:mm a').format(cycle.dateStarted!)
                    : 'N/A'),
                const SizedBox(height: 8),
                _buildInfoRow('Date Ended', 
                  cycle.dateEnded != null 
                    ? DateFormat('MMM d, yyyy h:mm a').format(cycle.dateEnded!)
                    : 'In Progress'),
                const SizedBox(height: 8),
                _buildInfoRow('% Completion', 
                  '${cycle.completionPercentage.toStringAsFixed(1)}%'),
                const SizedBox(height: 8),
                _buildInfoRow('Total Duration', 
                  _formatDuration(cycle.totalDuration)),
                const SizedBox(height: 16),

                // Total Call Statistics
                Text(
                  'Total Call Statistics:',
                  style: AppleTypography.withAppleFont(
                    AppleTypography.subtitle2.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Call events list
                if (cycle.callEvents.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      'No calls in this cycle',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  )
                else
                  ...cycle.callEvents.map((event) => _buildCallEventRow(event)).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: AppleTypography.withAppleFont(
              AppleTypography.body2.copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppleTypography.withAppleFont(
              AppleTypography.body2.copyWith(
                color: Colors.grey[900],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCallEventRow(CallEventData event) {
    // Format duration in minutes
    String durationText = 'N/A';
    if (event.durationSeconds != null && event.durationSeconds! >= 60) {
      final minutes = (event.durationSeconds! / 60).floor();
      durationText = '${minutes}m';
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4, top: 4),
      child: Row(
        children: [
          // Arrow indicator
          Icon(
            event.wasAnswered ? Icons.arrow_forward : Icons.arrow_forward_outlined,
            size: 16,
            color: event.wasAnswered ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          // Contact name only (no phone number)
          Expanded(
            child: Text(
              event.contactName,
              style: AppleTypography.withAppleFont(
                AppleTypography.body2.copyWith(
                  color: event.wasAnswered ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ),
          ),
          // Duration
          Text(
            durationText,
            style: AppleTypography.withAppleFont(
              AppleTypography.caption.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Time
          Text(
            DateFormat('h:mm a').format(event.timestamp),
            style: AppleTypography.withAppleFont(
              AppleTypography.caption.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Data models
class CycleData {
  final int cycleNumber;
  final String cycleId;
  final DateTime? dateStarted;
  final DateTime? dateEnded;
  final double completionPercentage;
  final Duration? totalDuration;
  final int totalContacts;
  final int completedContacts;
  final int outgoingCalls;
  final List<CallEventData> callEvents;

  CycleData({
    required this.cycleNumber,
    required this.cycleId,
    this.dateStarted,
    this.dateEnded,
    required this.completionPercentage,
    this.totalDuration,
    required this.totalContacts,
    required this.completedContacts,
    required this.outgoingCalls,
    required this.callEvents,
  });
}

class CallEventData {
  final String contactName;
  final String contactPhone;
  final DateTime timestamp;
  final bool wasAnswered;
  final double? durationSeconds;

  CallEventData({
    required this.contactName,
    required this.contactPhone,
    required this.timestamp,
    required this.wasAnswered,
    this.durationSeconds,
  });
}
