// Donut chart showing the proportion of call outcomes (answered, missed,
// voicemail, etc.) within a given time range. Uses fl_chart's PieChart.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:flutter_application_1/theme/app_colors.dart';
import 'package:flutter_application_1/theme/components/app_components.dart';
import 'package:intl/intl.dart';

class CallOutcomeDonutChart extends StatefulWidget {
  final String? selectedTimeRange;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final Function(String)? onTimeRangeChanged;
  final VoidCallback? onCustomRangeSelected;
  final String? targetUserId;

  const CallOutcomeDonutChart({
    Key? key,
    this.selectedTimeRange,
    this.customStartDate,
    this.customEndDate,
    this.onTimeRangeChanged,
    this.onCustomRangeSelected,
    this.targetUserId,
  }) : super(key: key);

  @override
  State<CallOutcomeDonutChart> createState() => _CallOutcomeDonutChartState();
}

class _CallOutcomeDonutChartState extends State<CallOutcomeDonutChart> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  int _touchedIndex = -1;
  String _selectedTimeRange = 'last7days'; // 'last7days', 'currentWeek', 'last30days', 'custom'
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Outcome categories
  int _connectedCalls = 0;
  int _noAnswerCalls = 0;
  int _busyFailedCalls = 0;
  int _voicemailCalls = 0;
  int _totalCalls = 0;

  String get _userId => widget.targetUserId ?? AuthService.firebase().currentUser!.id;

  String get currentTimeRange => widget.selectedTimeRange ?? _selectedTimeRange;
  DateTime? get currentStartDate => widget.customStartDate ?? _customStartDate;
  DateTime? get currentEndDate => widget.customEndDate ?? _customEndDate;
  bool get isExternallyControlled => widget.selectedTimeRange != null;

  @override
  void initState() {
    super.initState();
    _fetchCallOutcomes();
  }

  @override
  void didUpdateWidget(CallOutcomeDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh data when external parameters change
    if (oldWidget.selectedTimeRange != widget.selectedTimeRange ||
        oldWidget.customStartDate != widget.customStartDate ||
        oldWidget.customEndDate != widget.customEndDate) {
      _fetchCallOutcomes();
    }
  }

  // Fetches call records for the date range and tallies them into
  // connected/no-answer/rejected/missed buckets for the donut chart.
  Future<void> _fetchCallOutcomes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Determine date range
      DateTime startDate;
      DateTime endDate = DateTime.now();

      if (currentTimeRange == 'currentWeek') {
        final now = DateTime.now();
        final currentWeekday = now.weekday;
        startDate = now.subtract(Duration(days: currentWeekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      } else if (currentTimeRange == 'last7days') {
        startDate = DateTime.now().subtract(const Duration(days: 6));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      } else if (currentTimeRange == 'last30days') {
        startDate = DateTime.now().subtract(const Duration(days: 29));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      } else {
        // Custom range
        if (currentStartDate == null || currentEndDate == null) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
        startDate = DateTime(currentStartDate!.year, currentStartDate!.month, currentStartDate!.day);
        endDate = DateTime(currentEndDate!.year, currentEndDate!.month, currentEndDate!.day, 23, 59, 59);
      }

      print('Fetching call outcomes for user: $_userId');
      print('Date range: $startDate to $endDate');

      // Fetch call history
      final QuerySnapshot querySnapshot = await _firestore
          .collection('call_history')
          .where('user_id', isEqualTo: _userId)
          .orderBy('timestamp', descending: true)
          .get();

      print('Total call records fetched: ${querySnapshot.docs.length}');

      // Reset counters
      int connected = 0;
      int noAnswer = 0;
      int busyFailed = 0;
      int voicemail = 0;
      int total = 0;

      for (var doc in querySnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final timestamp = (data['timestamp'] as Timestamp).toDate();

          // Filter by date range
          if (timestamp.isBefore(startDate) || timestamp.isAfter(endDate)) {
            continue;
          }

          total++;

          final duration = (data['duration'] as num?)?.toDouble() ?? 0.0;
          final callType = data['call_type'] as String? ?? '';
          
          bool answered;
          if (data['answered'] is bool) {
            answered = data['answered'] as bool;
          } else if (data['answered'] is int) {
            answered = (data['answered'] as int) == 1;
          } else {
            answered = false;
          }

          // Categorize the call outcome
          // Note: Voicemail detection would require additional data field
          // For now, we'll use duration as a proxy (very short calls might be voicemail)
          
          if (callType.toLowerCase() == 'missed' || 
              (callType.toLowerCase() == 'incoming' && !answered)) {
            noAnswer++;
          } else if (answered && duration > 0) {
            // Check if it might be voicemail (connected but very short)
            if (duration < 10 && duration > 0) {
              voicemail++;
            } else {
              connected++;
            }
          } else if (!answered && duration == 0) {
            // Could be busy or failed
            busyFailed++;
          } else {
            // Default case
            noAnswer++;
          }
        } catch (e) {
          print('Error parsing call record: $e');
        }
      }

      print('Call outcomes - Connected: $connected, No Answer: $noAnswer, Busy/Failed: $busyFailed, Voicemail: $voicemail');

      if (mounted) {
        setState(() {
          _connectedCalls = connected;
          _noAnswerCalls = noAnswer;
          _busyFailedCalls = busyFailed;
          _voicemailCalls = voicemail;
          _totalCalls = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching call outcomes: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  double _getPercentage(int count) {
    if (_totalCalls == 0) return 0;
    return (count / _totalCalls) * 100;
  }

  String _getTimeRangeLabel() {
    if (currentTimeRange == 'currentWeek') {
      return 'Current Week';
    } else if (currentTimeRange == 'last7days') {
      return 'Last 7 Days';
    } else if (currentTimeRange == 'last30days') {
      return 'Last 30 Days';
    } else if (currentTimeRange == 'custom' && currentStartDate != null && currentEndDate != null) {
      return '${DateFormat('MMM d').format(currentStartDate!)} - ${DateFormat('MMM d, yyyy').format(currentEndDate!)}';
    } else {
      return 'Custom Range';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Call Outcome Overview',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppDesignTokens.neutral800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Overall success rate at a glance',
            style: TextStyle(
              fontSize: 14,
              color: AppDesignTokens.neutral600,
            ),
          ),
          const SizedBox(height: 16),

          // Time range selector (only show if not externally controlled)
          if (!isExternallyControlled)
            Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Period:',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppDesignTokens.neutral700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Current Week'),
                            selected: _selectedTimeRange == 'currentWeek',
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedTimeRange = 'currentWeek';
                                });
                                _fetchCallOutcomes();
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Last 7 Days'),
                            selected: _selectedTimeRange == 'last7days',
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedTimeRange = 'last7days';
                                });
                                _fetchCallOutcomes();
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Last 30 Days'),
                            selected: _selectedTimeRange == 'last30days',
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedTimeRange = 'last30days';
                                });
                                _fetchCallOutcomes();
                              }
                            },
                          ),
                          ChoiceChip(
                            label: Text(_selectedTimeRange == 'custom' && _customStartDate != null
                                ? 'Custom Range'
                                : 'Select Custom'),
                            selected: _selectedTimeRange == 'custom',
                            onSelected: (selected) {
                              // Add custom date picker functionality if needed
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),

          // Donut Chart
          if (_isLoading)
            const SizedBox(
              height: 400,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_totalCalls == 0)
            SizedBox(
              height: 400,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pie_chart_outline, size: 64, color: AppDesignTokens.neutral400),
                    const SizedBox(height: 16),
                    Text(
                      'No call data for ${_getTimeRangeLabel().toLowerCase()}',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppDesignTokens.neutral600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Make some calls to see outcome statistics',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppDesignTokens.neutral500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                SizedBox(
                  height: 300,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (FlTouchEvent event, pieTouchResponse) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    pieTouchResponse == null ||
                                    pieTouchResponse.touchedSection == null) {
                                  _touchedIndex = -1;
                                  return;
                                }
                                _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                          borderData: FlBorderData(show: false),
                          sectionsSpace: 2,
                          centerSpaceRadius: 80,
                          sections: _buildPieChartSections(),
                        ),
                      ),
                      // Center content
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_totalCalls',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: AppDesignTokens.neutral800,
                            ),
                          ),
                          Text(
                            'Total Calls',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppDesignTokens.neutral600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getTimeRangeLabel(),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppDesignTokens.neutral500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Legend
                _buildLegend(),
              ],
            ),

          const SizedBox(height: 24),

          // Detailed statistics
          if (!_isLoading && _totalCalls > 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppDesignTokens.neutral100,
                borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Outcome Breakdown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppDesignTokens.neutral800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildOutcomeRow(
                    'Connected',
                    _connectedCalls,
                    _getPercentage(_connectedCalls),
                    AppDesignTokens.success,
                  ),
                  const SizedBox(height: 12),
                  _buildOutcomeRow(
                    'No Answer',
                    _noAnswerCalls,
                    _getPercentage(_noAnswerCalls),
                    AppDesignTokens.warning,
                  ),
                  const SizedBox(height: 12),
                  _buildOutcomeRow(
                    'Busy/Failed',
                    _busyFailedCalls,
                    _getPercentage(_busyFailedCalls),
                    AppDesignTokens.danger,
                  ),
                  const SizedBox(height: 12),
                  _buildOutcomeRow(
                    'Voicemail',
                    _voicemailCalls,
                    _getPercentage(_voicemailCalls),
                    AppColors.coral,
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Success Rate',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppDesignTokens.neutral800,
                        ),
                      ),
                      Text(
                        '${_getPercentage(_connectedCalls).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppDesignTokens.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Converts the four outcome counts into PieChartSectionData objects.
  // The touched section expands slightly to give a visual highlight.
  List<PieChartSectionData> _buildPieChartSections() {
    return [
      PieChartSectionData(
        color: AppDesignTokens.success,
        value: _connectedCalls.toDouble(),
        title: _touchedIndex == 0 ? '${_getPercentage(_connectedCalls).toStringAsFixed(1)}%' : '',
        radius: _touchedIndex == 0 ? 70 : 60,
        titleStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: AppDesignTokens.warning,
        value: _noAnswerCalls.toDouble(),
        title: _touchedIndex == 1 ? '${_getPercentage(_noAnswerCalls).toStringAsFixed(1)}%' : '',
        radius: _touchedIndex == 1 ? 70 : 60,
        titleStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: AppDesignTokens.danger,
        value: _busyFailedCalls.toDouble(),
        title: _touchedIndex == 2 ? '${_getPercentage(_busyFailedCalls).toStringAsFixed(1)}%' : '',
        radius: _touchedIndex == 2 ? 70 : 60,
        titleStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: AppColors.coral,
        value: _voicemailCalls.toDouble(),
        title: _touchedIndex == 3 ? '${_getPercentage(_voicemailCalls).toStringAsFixed(1)}%' : '',
        radius: _touchedIndex == 3 ? 70 : 60,
        titleStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _buildLegendItem(
          'Connected',
          AppDesignTokens.success,
          _connectedCalls,
          _getPercentage(_connectedCalls),
        ),
        _buildLegendItem(
          'No Answer',
          AppDesignTokens.warning,
          _noAnswerCalls,
          _getPercentage(_noAnswerCalls),
        ),
        _buildLegendItem(
          'Busy/Failed',
          AppDesignTokens.danger,
          _busyFailedCalls,
          _getPercentage(_busyFailedCalls),
        ),
        _buildLegendItem(
          'Voicemail',
          AppColors.coral,
          _voicemailCalls,
          _getPercentage(_voicemailCalls),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, int count, double percentage) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: $count (${percentage.toStringAsFixed(1)}%)',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutcomeRow(String label, int count, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              '$count (${percentage.toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: AppDesignTokens.neutral300,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
        ),
      ],
    );
  }
}
