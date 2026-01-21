import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:intl/intl.dart';

class CallDurationChart extends StatefulWidget {
  const CallDurationChart({Key? key}) : super(key: key);

  @override
  State<CallDurationChart> createState() => _CallDurationChartState();
}

class _CallDurationChartState extends State<CallDurationChart> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String _selectedTimeRange = 'last7days';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Duration bins data
  final Map<String, DurationBinData> _durationBins = {
    '0-1min': DurationBinData(label: '0-1min', minSeconds: 0, maxSeconds: 60),
    '1-3min': DurationBinData(label: '1-3min', minSeconds: 60, maxSeconds: 180),
    '3-5min': DurationBinData(label: '3-5min', minSeconds: 180, maxSeconds: 300),
    '5-10min': DurationBinData(label: '5-10min', minSeconds: 300, maxSeconds: 600),
    '10+min': DurationBinData(label: '10+min', minSeconds: 600, maxSeconds: double.infinity),
  };

  // Statistical data
  double _medianDuration = 0;
  double _percentile25 = 0;
  double _percentile50 = 0;
  double _percentile75 = 0;
  List<double> _allDurations = [];

  String get _userId => AuthService.firebase().currentUser!.id;

  @override
  void initState() {
    super.initState();
    _fetchCallData();
  }

  Future<void> _fetchCallData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Determine date range
      DateTime startDate;
      DateTime endDate = DateTime.now();

      if (_selectedTimeRange == 'last7days') {
        startDate = DateTime.now().subtract(const Duration(days: 6));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      } else if (_selectedTimeRange == 'currentWeek') {
        final now = DateTime.now();
        final currentWeekday = now.weekday;
        startDate = now.subtract(Duration(days: currentWeekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      } else if (_selectedTimeRange == 'last30days') {
        startDate = DateTime.now().subtract(const Duration(days: 29));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      } else {
        if (_customStartDate == null || _customEndDate == null) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
        startDate = DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day);
        endDate = DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59);
      }

      print('Fetching call durations for user: $_userId');
      print('Date range: $startDate to $endDate');

      // Fetch call history
      final QuerySnapshot querySnapshot = await _firestore
          .collection('call_history')
          .where('user_id', isEqualTo: _userId)
          .orderBy('timestamp', descending: true)
          .get();

      print('Total call records fetched: ${querySnapshot.docs.length}');

      // Reset bins
      for (var bin in _durationBins.values) {
        bin.reset();
      }

      List<double> allDurations = [];

      int recordsInRange = 0;
      for (var doc in querySnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final timestamp = (data['timestamp'] as Timestamp).toDate();

          // Filter by date range
          if (timestamp.isBefore(startDate) || timestamp.isAfter(endDate)) {
            continue;
          }

          recordsInRange++;

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

          // Only include calls with duration > 0
          if (duration > 0) {
            allDurations.add(duration);

            // Determine if successful
            bool isSuccessful = false;
            if (callType.toLowerCase() != 'missed' && (answered || duration > 0)) {
              isSuccessful = true;
            }

            // Bin the duration
            for (var bin in _durationBins.values) {
              if (duration >= bin.minSeconds && duration < bin.maxSeconds) {
                if (isSuccessful) {
                  bin.successfulCalls++;
                } else {
                  bin.unsuccessfulCalls++;
                }
                break;
              }
            }
          }
        } catch (e) {
          print('Error parsing call record: $e');
        }
      }

      print('Records in date range: $recordsInRange');
      print('Calls with duration > 0: ${allDurations.length}');

      // Calculate statistics
      if (allDurations.isNotEmpty) {
        allDurations.sort();
        _allDurations = allDurations;

        _percentile25 = _calculatePercentile(allDurations, 25);
        _percentile50 = _calculatePercentile(allDurations, 50);
        _percentile75 = _calculatePercentile(allDurations, 75);
        _medianDuration = _percentile50;

        print('Median: $_medianDuration seconds');
        print('25th percentile: $_percentile25 seconds');
        print('75th percentile: $_percentile75 seconds');
      } else {
        _allDurations = [];
        _percentile25 = 0;
        _percentile50 = 0;
        _percentile75 = 0;
        _medianDuration = 0;
      }

      // Print bin data
      for (var bin in _durationBins.values) {
        print('${bin.label}: S=${bin.successfulCalls}, U=${bin.unsuccessfulCalls}');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching call duration data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  double _calculatePercentile(List<double> sortedData, int percentile) {
    if (sortedData.isEmpty) return 0;
    
    double index = (percentile / 100.0) * (sortedData.length - 1);
    int lowerIndex = index.floor();
    int upperIndex = index.ceil();
    
    if (lowerIndex == upperIndex) {
      return sortedData[lowerIndex];
    }
    
    double weight = index - lowerIndex;
    return sortedData[lowerIndex] * (1 - weight) + sortedData[upperIndex] * weight;
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedTimeRange = 'custom';
      });
      _fetchCallData();
    }
  }

  String _formatDuration(double seconds) {
    if (seconds < 60) {
      return '${seconds.toInt()}s';
    } else {
      int minutes = (seconds / 60).floor();
      int remainingSeconds = (seconds % 60).toInt();
      return '${minutes}m ${remainingSeconds}s';
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
            'Call Duration Analysis',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Understand typical call lengths and time spent per call',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),

          // Time range selector
          Row(
            children: [
              Text(
                'Time Range:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Last 7 Days'),
                      selected: _selectedTimeRange == 'last7days',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedTimeRange = 'last7days';
                          });
                          _fetchCallData();
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Current Week'),
                      selected: _selectedTimeRange == 'currentWeek',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedTimeRange = 'currentWeek';
                          });
                          _fetchCallData();
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
                          _fetchCallData();
                        }
                      },
                    ),
                    ChoiceChip(
                      label: Text(_selectedTimeRange == 'custom' && _customStartDate != null
                          ? 'Custom Range'
                          : 'Select Custom'),
                      selected: _selectedTimeRange == 'custom',
                      onSelected: (selected) {
                        _selectDateRange();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_selectedTimeRange == 'custom' && _customStartDate != null && _customEndDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Selected: ${DateFormat('MMM d').format(_customStartDate!)} - ${DateFormat('MMM d, yyyy').format(_customEndDate!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendItem('Successful', Colors.green),
              _buildLegendItem('Unsuccessful', Colors.red),
              _buildLegendItem('Median', Colors.blue),
              _buildLegendItem('Percentiles', Colors.orange),
            ],
          ),

          const SizedBox(height: 24),

          // Chart
          if (_isLoading)
            const SizedBox(
              height: 350,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_allDurations.isEmpty)
            SizedBox(
              height: 350,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer_off, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No call duration data found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try selecting a different time range',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 350,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxY(),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.blueGrey,
                      tooltipRoundedRadius: 8,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final bin = _durationBins.values.elementAt(groupIndex);
                        final isSuccessful = rodIndex == 0;
                        final count = isSuccessful ? bin.successfulCalls : bin.unsuccessfulCalls;
                        
                        return BarTooltipItem(
                          '${bin.label}\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text: '${isSuccessful ? "Successful" : "Unsuccessful"}: $count',
                              style: TextStyle(
                                color: isSuccessful ? Colors.green : Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < _durationBins.length) {
                            final label = _durationBins.values.elementAt(index).label;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: _getMaxY() > 10 ? 5 : 1,
                        reservedSize: 42,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _getMaxY() > 10 ? 5 : 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade300,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  barGroups: _buildBarGroups(),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      // Median line
                      HorizontalLine(
                        y: _convertDurationToBarPosition(_medianDuration),
                        color: Colors.blue,
                        strokeWidth: 2,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 5, bottom: 5),
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          labelResolver: (line) => 'Median: ${_formatDuration(_medianDuration)}',
                        ),
                      ),
                      // 25th percentile
                      HorizontalLine(
                        y: _convertDurationToBarPosition(_percentile25),
                        color: Colors.orange.shade300,
                        strokeWidth: 1.5,
                        dashArray: [3, 3],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topLeft,
                          padding: const EdgeInsets.only(left: 5, bottom: 5),
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          labelResolver: (line) => '25th: ${_formatDuration(_percentile25)}',
                        ),
                      ),
                      // 75th percentile
                      HorizontalLine(
                        y: _convertDurationToBarPosition(_percentile75),
                        color: Colors.orange.shade300,
                        strokeWidth: 1.5,
                        dashArray: [3, 3],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.bottomLeft,
                          padding: const EdgeInsets.only(left: 5, top: 5),
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          labelResolver: (line) => '75th: ${_formatDuration(_percentile75)}',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Statistics summary
          if (!_isLoading && _allDurations.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Statistical Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStatRow('Total Calls', '${_allDurations.length}'),
                  _buildStatRow('Median Duration', _formatDuration(_medianDuration)),
                  _buildStatRow('25th Percentile', _formatDuration(_percentile25)),
                  _buildStatRow('75th Percentile', _formatDuration(_percentile75)),
                  _buildStatRow('Average Duration', _formatDuration(_allDurations.reduce((a, b) => a + b) / _allDurations.length)),
                  const SizedBox(height: 16),
                  Text(
                    'Duration Distribution',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._durationBins.values.map((bin) {
                    final total = bin.successfulCalls + bin.unsuccessfulCalls;
                    if (total == 0) return const SizedBox.shrink();
                    
                    final percentage = (total / _allDurations.length * 100).toStringAsFixed(1);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 70,
                            child: Text(
                              bin.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Row(
                              children: [
                                _buildStatBadge('S: ${bin.successfulCalls}', Colors.green),
                                const SizedBox(width: 8),
                                _buildStatBadge('U: ${bin.unsuccessfulCalls}', Colors.red),
                                const SizedBox(width: 8),
                                Text(
                                  'Total: $total ($percentage%)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
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
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    List<BarChartGroupData> groups = [];
    int index = 0;

    for (var bin in _durationBins.values) {
      groups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: bin.successfulCalls.toDouble(),
              color: Colors.green,
              width: 12,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            BarChartRodData(
              toY: bin.unsuccessfulCalls.toDouble(),
              color: Colors.red,
              width: 12,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
      index++;
    }

    return groups;
  }

  double _getMaxY() {
    double max = 0;
    for (var bin in _durationBins.values) {
      final binMax = (bin.successfulCalls > bin.unsuccessfulCalls 
          ? bin.successfulCalls 
          : bin.unsuccessfulCalls).toDouble();
      if (binMax > max) max = binMax;
    }
    return max > 0 ? max + 5 : 10;
  }

  // Convert duration in seconds to approximate bar position for horizontal lines
  double _convertDurationToBarPosition(double durationSeconds) {
    // This is a visual approximation - the percentile lines show where on the frequency
    // axis (Y) the percentile would appear if we were to stack all calls
    // For simplicity, we'll map it as a percentage of max frequency
    if (_allDurations.isEmpty) return 0;
    
    // Calculate what percentage of calls fall below this duration
    int countBelow = _allDurations.where((d) => d <= durationSeconds).length;
    double percentageBelow = countBelow / _allDurations.length;
    
    // Map to the y-axis range
    return percentageBelow * _getMaxY();
  }
}

class DurationBinData {
  final String label;
  final double minSeconds;
  final double maxSeconds;
  int successfulCalls = 0;
  int unsuccessfulCalls = 0;

  DurationBinData({
    required this.label,
    required this.minSeconds,
    required this.maxSeconds,
  });

  void reset() {
    successfulCalls = 0;
    unsuccessfulCalls = 0;
  }
}
