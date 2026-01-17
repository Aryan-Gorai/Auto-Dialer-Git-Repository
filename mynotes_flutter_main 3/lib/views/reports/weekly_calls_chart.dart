import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:intl/intl.dart';

class WeeklyCallsChart extends StatefulWidget {
  const WeeklyCallsChart({Key? key}) : super(key: key);

  @override
  State<WeeklyCallsChart> createState() => _WeeklyCallsChartState();
}

class _WeeklyCallsChartState extends State<WeeklyCallsChart> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String _selectedTimeRange = 'last7days'; // 'last7days', 'currentWeek', 'custom'
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  
  // Data for the chart
  Map<int, CallDayData> _callDataByWeekday = {}; // 1=Mon, 7=Sun
  List<FlSpot> _successfulSpots = [];
  List<FlSpot> _failedSpots = [];
  List<FlSpot> _missedSpots = [];
  List<FlSpot> _rollingAverageSpots = [];

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
      // Determine date range based on selected option
      DateTime startDate;
      DateTime endDate = DateTime.now();

      if (_selectedTimeRange == 'last7days') {
        startDate = DateTime.now().subtract(const Duration(days: 6));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      } else if (_selectedTimeRange == 'currentWeek') {
        // Get current week (Monday to Sunday)
        final now = DateTime.now();
        final currentWeekday = now.weekday; // 1=Mon, 7=Sun
        startDate = now.subtract(Duration(days: currentWeekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      } else {
        // Custom range
        if (_customStartDate == null || _customEndDate == null) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
        startDate = DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day);
        endDate = DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59);
      }

      // Fetch call history from Firebase
      // Note: Firestore doesn't support multiple range queries without a composite index
      // So we fetch all user's call history and filter in memory
      print('Fetching call history for user: $_userId');
      print('Date range: $startDate to $endDate');
      
      final QuerySnapshot querySnapshot = await _firestore
          .collection('call_history')
          .where('user_id', isEqualTo: _userId)
          .orderBy('timestamp', descending: true)
          .get();

      print('Total call records fetched: ${querySnapshot.docs.length}');

      // Aggregate data by day of week
      final Map<int, CallDayData> dataByWeekday = {
        1: CallDayData(weekday: 1, dayName: 'Mon'),
        2: CallDayData(weekday: 2, dayName: 'Tue'),
        3: CallDayData(weekday: 3, dayName: 'Wed'),
        4: CallDayData(weekday: 4, dayName: 'Thu'),
        5: CallDayData(weekday: 5, dayName: 'Fri'),
        6: CallDayData(weekday: 6, dayName: 'Sat'),
        7: CallDayData(weekday: 7, dayName: 'Sun'),
      };

      int recordsInRange = 0;
      for (var doc in querySnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final timestamp = (data['timestamp'] as Timestamp).toDate();
          
          // Filter by date range in memory
          if (timestamp.isBefore(startDate) || timestamp.isAfter(endDate)) {
            continue;
          }
          
          recordsInRange++;
          final weekday = timestamp.weekday; // 1=Mon, 7=Sun
          
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

          // Categorize calls - made more inclusive
          // Successful: Outgoing calls that were answered OR have duration > 0
          // Failed: Calls that weren't answered and have 0 duration (excluding Missed type)
          // Missed: Explicitly marked as Missed OR incoming calls not answered
          
          if (callType.toLowerCase() == 'missed') {
            dataByWeekday[weekday]!.missedCallbacks++;
            print('Missed call on ${dataByWeekday[weekday]!.dayName}');
          } else if (callType.toLowerCase() == 'incoming' && !answered) {
            dataByWeekday[weekday]!.missedCallbacks++;
            print('Missed incoming call on ${dataByWeekday[weekday]!.dayName}');
          } else if (answered || duration > 0) {
            // Successful if answered OR has duration (covers most outgoing calls)
            dataByWeekday[weekday]!.successfulCalls++;
            print('Successful call on ${dataByWeekday[weekday]!.dayName}, duration: $duration, answered: $answered');
          } else {
            dataByWeekday[weekday]!.failedCalls++;
            print('Failed call on ${dataByWeekday[weekday]!.dayName}');
          }
        } catch (e) {
          print('Error parsing call record: $e');
        }
      }

      print('Records in date range: $recordsInRange');
      for (var day in dataByWeekday.values) {
        print('${day.dayName}: S=${day.successfulCalls}, F=${day.failedCalls}, M=${day.missedCallbacks}');
      }

      // Calculate rolling average (7-day window)
      final List<double> totalCallsPerDay = [];
      for (int i = 1; i <= 7; i++) {
        final dayData = dataByWeekday[i]!;
        totalCallsPerDay.add((dayData.successfulCalls + dayData.failedCalls + dayData.missedCallbacks).toDouble());
      }

      // Create chart data spots
      final List<FlSpot> successfulSpots = [];
      final List<FlSpot> failedSpots = [];
      final List<FlSpot> missedSpots = [];
      final List<FlSpot> rollingAverageSpots = [];

      for (int i = 1; i <= 7; i++) {
        final dayData = dataByWeekday[i]!;
        final xValue = (i - 1).toDouble();
        
        successfulSpots.add(FlSpot(xValue, dayData.successfulCalls.toDouble()));
        failedSpots.add(FlSpot(xValue, dayData.failedCalls.toDouble()));
        missedSpots.add(FlSpot(xValue, dayData.missedCallbacks.toDouble()));
        
        // Calculate rolling average (simple moving average across all days)
        double rollingAvg = totalCallsPerDay.reduce((a, b) => a + b) / 7;
        rollingAverageSpots.add(FlSpot(xValue, rollingAvg));
      }

      if (mounted) {
        setState(() {
          _callDataByWeekday = dataByWeekday;
          _successfulSpots = successfulSpots;
          _failedSpots = failedSpots;
          _missedSpots = missedSpots;
          _rollingAverageSpots = rollingAverageSpots;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching call data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Calling Trends',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track calling patterns and identify peak productivity days',
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
              _buildLegendItem('Failed', Colors.red),
              _buildLegendItem('Missed Callbacks', Colors.orange),
              _buildLegendItem('7-Day Avg', Colors.blue.shade300),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Chart
          if (_isLoading)
            const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_callDataByWeekday.isEmpty || _getMaxY() == 0)
            SizedBox(
              height: 300,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone_disabled, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No call data found for selected period',
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
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 1,
                    verticalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade300,
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade300,
                        strokeWidth: 1,
                      );
                    },
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
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final weekday = value.toInt() + 1;
                          final dayData = _callDataByWeekday[weekday];
                          if (dayData != null) {
                            return Text(
                              dayData.dayName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
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
                        interval: 5,
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
                  minX: 0,
                  maxX: 6,
                  minY: 0,
                  maxY: _getMaxY() + 5,
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => Colors.blueGrey,
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                          final weekday = barSpot.x.toInt() + 1;
                          final dayData = _callDataByWeekday[weekday];
                          
                          if (dayData == null) return null;
                          
                          String label = '';
                          Color color = Colors.white;
                          
                          if (barSpot.barIndex == 0) {
                            label = 'Successful: ${dayData.successfulCalls}';
                            color = Colors.green;
                          } else if (barSpot.barIndex == 1) {
                            label = 'Failed: ${dayData.failedCalls}';
                            color = Colors.red;
                          } else if (barSpot.barIndex == 2) {
                            label = 'Missed: ${dayData.missedCallbacks}';
                            color = Colors.orange;
                          } else if (barSpot.barIndex == 3) {
                            label = 'Avg: ${barSpot.y.toStringAsFixed(1)}';
                            color = Colors.blue.shade300;
                          }
                          
                          return LineTooltipItem(
                            label,
                            TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                    handleBuiltInTouches: true,
                    getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                      return spotIndexes.map((spotIndex) {
                        return TouchedSpotIndicatorData(
                          FlLine(
                            color: Colors.grey.shade800,
                            strokeWidth: 2,
                          ),
                          FlDotData(
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 6,
                                color: barData.color ?? Colors.blue,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                        );
                      }).toList();
                    },
                  ),
                  lineBarsData: [
                    // Successful calls line
                    LineChartBarData(
                      spots: _successfulSpots,
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withOpacity(0.1),
                      ),
                    ),
                    // Failed calls line
                    LineChartBarData(
                      spots: _failedSpots,
                      isCurved: true,
                      color: Colors.red,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.red.withOpacity(0.1),
                      ),
                    ),
                    // Missed callbacks line
                    LineChartBarData(
                      spots: _missedSpots,
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.orange.withOpacity(0.1),
                      ),
                    ),
                    // Rolling average line
                    LineChartBarData(
                      spots: _rollingAverageSpots,
                      isCurved: false,
                      color: Colors.blue.shade300,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      dashArray: [5, 5], // Dashed line
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 24),
          
          // Daily breakdown summary
          if (!_isLoading && _callDataByWeekday.isNotEmpty && _getMaxY() > 0)
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
                    'Daily Breakdown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._callDataByWeekday.values.map((dayData) {
                    final total = dayData.successfulCalls + dayData.failedCalls + dayData.missedCallbacks;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 50,
                            child: Text(
                              dayData.dayName,
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
                                _buildStatBadge('S: ${dayData.successfulCalls}', Colors.green),
                                const SizedBox(width: 8),
                                _buildStatBadge('F: ${dayData.failedCalls}', Colors.red),
                                const SizedBox(width: 8),
                                _buildStatBadge('M: ${dayData.missedCallbacks}', Colors.orange),
                                const SizedBox(width: 8),
                                Text(
                                  'Total: $total',
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

  double _getMaxY() {
    double max = 0;
    for (var data in _callDataByWeekday.values) {
      final dayMax = (data.successfulCalls + data.failedCalls + data.missedCallbacks).toDouble();
      if (dayMax > max) max = dayMax;
    }
    for (var spot in _rollingAverageSpots) {
      if (spot.y > max) max = spot.y;
    }
    return max > 0 ? max : 10;
  }
}

class CallDayData {
  final int weekday;
  final String dayName;
  int successfulCalls = 0;
  int failedCalls = 0;
  int missedCallbacks = 0;

  CallDayData({
    required this.weekday,
    required this.dayName,
  });
}
