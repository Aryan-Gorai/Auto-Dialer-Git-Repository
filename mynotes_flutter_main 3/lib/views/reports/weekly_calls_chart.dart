import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:intl/intl.dart';

class WeeklyCallsChart extends StatefulWidget {
  final String? selectedTimeRange;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final String? listFilter; // Optional: list_name to filter by specific list
  final Function(String)? onTimeRangeChanged;
  final VoidCallback? onCustomRangeSelected;

  const WeeklyCallsChart({
    Key? key,
    this.selectedTimeRange,
    this.customStartDate,
    this.customEndDate,
    this.listFilter,
    this.onTimeRangeChanged,
    this.onCustomRangeSelected,
  }) : super(key: key);

  @override
  State<WeeklyCallsChart> createState() => _WeeklyCallsChartState();
}

class _WeeklyCallsChartState extends State<WeeklyCallsChart> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String _selectedTimeRange = 'last7days'; // 'last7days', 'currentWeek', 'custom'
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  
  // Data for the chart - now supports both daily and weekly aggregation
  Map<int, CallDayData> _callDataByWeekday = {}; // For weekly view: 1=Mon, 7=Sun
  Map<String, DailyCallData> _callDataByDate = {}; // For custom ranges: date string -> data
  List<FlSpot> _successfulSpots = [];
  List<FlSpot> _failedSpots = [];
  List<FlSpot> _missedSpots = [];
  List<FlSpot> _rollingAverageSpots = [];
  bool _useWeeklyView = true; // true = weekday aggregation, false = daily view

  String? get _userId => AuthService.firebase().currentUser?.id;

  String get currentTimeRange => widget.selectedTimeRange ?? _selectedTimeRange;
  DateTime? get currentStartDate => widget.customStartDate ?? _customStartDate;
  DateTime? get currentEndDate => widget.customEndDate ?? _customEndDate;
  bool get isExternallyControlled => widget.selectedTimeRange != null;

  @override
  void initState() {
    super.initState();
    _fetchCallData();
  }

  @override
  void didUpdateWidget(WeeklyCallsChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh data when external parameters change
    if (oldWidget.selectedTimeRange != widget.selectedTimeRange ||
        oldWidget.customStartDate != widget.customStartDate ||
        oldWidget.customEndDate != widget.customEndDate ||
        oldWidget.listFilter != widget.listFilter) {
      _fetchCallData();
    }
  }

  // Helper function to normalize phone numbers for comparison
  String _normalizePhoneNumber(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length >= 9) {
      return digitsOnly.substring(digitsOnly.length - 9);
    }
    return digitsOnly;
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
      final parsedDouble = double.tryParse(value);
      if (parsedDouble != null) return parsedDouble.round();
    }
    return 0;
  }

  Future<void> _fetchCallData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Determine date range based on selected option
      DateTime startDate;
      DateTime endDate = DateTime.now();

      if (currentTimeRange == 'last7days') {
        startDate = DateTime.now().subtract(const Duration(days: 6));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        _useWeeklyView = true;
      } else if (currentTimeRange == 'currentWeek') {
        // Get current week (Monday to Sunday)
        final now = DateTime.now();
        final currentWeekday = now.weekday; // 1=Mon, 7=Sun
        startDate = now.subtract(Duration(days: currentWeekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        _useWeeklyView = true;
      } else if (currentTimeRange == 'last30days') {
        startDate = DateTime.now().subtract(const Duration(days: 29));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        _useWeeklyView = false; // Use daily view for 30 days
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
        // Use daily view for custom ranges longer than 7 days
        int daysDiff = endDate.difference(startDate).inDays + 1;
        _useWeeklyView = daysDiff <= 7;
      }

      // If list filter is set, use list_cycles data instead of call_history
      if (widget.listFilter != null && widget.listFilter!.isNotEmpty) {
        print('📊 Using list_cycles data for list: ${widget.listFilter}');
        await _fetchFromListCycles(startDate, endDate);
        return;
      }

      // Otherwise use call_history as before
      print('📊 Using call_history data (no list filter)');
      await _fetchFromCallHistory(startDate, endDate);
    } catch (e) {
      print('❌ Error fetching call data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchFromListCycles(DateTime startDate, DateTime endDate) async {
    print('📅 Fetching list_cycles for "${widget.listFilter}" from $startDate to $endDate');

    final userId = _userId;
    if (userId == null) {
      print('⚠️ No authenticated user found. Skipping list_cycles fetch.');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    // Query list_cycles for the specified list
    final cyclesSnapshot = await _firestore
        .collection('list_cycles')
        .where('user_id', isEqualTo: userId)
        .where('list_name', isEqualTo: widget.listFilter)
        .get();

    print('📂 Found ${cyclesSnapshot.docs.length} cycles');

    if (_useWeeklyView) {
      _processWeeklyCycleData(cyclesSnapshot, startDate, endDate);
    } else {
      _processDailyCycleData(cyclesSnapshot, startDate, endDate);
    }
  }

  Future<void> _fetchFromCallHistory(DateTime startDate, DateTime endDate) async {
    // Fetch call history from Firebase
    print('📞 Fetching call history from call_history collection');
    print('Date range: $startDate to $endDate');

    final QuerySnapshot querySnapshot = await _firestore
        .collection('call_history')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    print('Total call records fetched: ${querySnapshot.docs.length}');

    if (_useWeeklyView) {
      // Aggregate by weekday
      _processWeeklyData(querySnapshot, startDate, endDate, {});
    } else {
      // Aggregate by specific dates
      _processDailyData(querySnapshot, startDate, endDate, {});
    }
  }

  void _processWeeklyCycleData(QuerySnapshot cyclesSnapshot, DateTime startDate, DateTime endDate) {
      // Aggregate by weekday from cycle_events
      final Map<int, CallDayData> dataByWeekday = {
        1: CallDayData(weekday: 1, dayName: 'Mon'),
        2: CallDayData(weekday: 2, dayName: 'Tue'),
        3: CallDayData(weekday: 3, dayName: 'Wed'),
        4: CallDayData(weekday: 4, dayName: 'Thu'),
        5: CallDayData(weekday: 5, dayName: 'Fri'),
        6: CallDayData(weekday: 6, dayName: 'Sat'),
        7: CallDayData(weekday: 7, dayName: 'Sun'),
      };

      int totalEvents = 0;
    
      for (var cycleDoc in cyclesSnapshot.docs) {
        final cycleData = cycleDoc.data() as Map<String, dynamic>;
      
        // Get cycle timestamp
        final startedAtClient = cycleData['started_at_client'] as Timestamp?;
        final startedAtServer = cycleData['started_at_server'] as Timestamp?;
        final cycleTimestamp = startedAtClient ?? startedAtServer;
      
        if (cycleTimestamp == null) continue;
      
        final cycleTime = cycleTimestamp.toDate();
      
        // Check if cycle is within date range
        if (cycleTime.isBefore(startDate) || cycleTime.isAfter(endDate)) {
          continue;
        }
      
        final weekday = cycleTime.weekday; // 1=Mon, 7=Sun
      
        // Get stats from cycle document
        final stats = cycleData['stats'];
        if (stats is Map<String, dynamic>) {
          final outgoing = _parseInt(stats['outgoing']);
          final cancelled = _parseInt(stats['cancelled']);
          final missed = _parseInt(stats['missed']);
        
          // outgoing = successful calls
          dataByWeekday[weekday]!.successfulCalls += outgoing;
          // cancelled = failed calls (no answer, hung up, etc)
          dataByWeekday[weekday]!.failedCalls += cancelled;
          // missed = missed/no answer
          dataByWeekday[weekday]!.missedCallbacks += missed;
        
          totalEvents += (outgoing + cancelled + missed);
        }
      }
    
      print('✅ Processed $totalEvents total call events');
    
      // Create chart data spots (same as before)
      final List<FlSpot> successfulSpots = [];
      final List<FlSpot> failedSpots = [];
      final List<FlSpot> missedSpots = [];
      final List<FlSpot> rollingAverageSpots = [];

      final List<double> totalCallsPerDay = [];
      for (int i = 1; i <= 7; i++) {
        final dayData = dataByWeekday[i]!;
        totalCallsPerDay.add((dayData.successfulCalls + dayData.failedCalls + dayData.missedCallbacks).toDouble());
      }

      for (int i = 1; i <= 7; i++) {
        final dayData = dataByWeekday[i]!;
        final xValue = (i - 1).toDouble();
      
        successfulSpots.add(FlSpot(xValue, dayData.successfulCalls.toDouble()));
        failedSpots.add(FlSpot(xValue, dayData.failedCalls.toDouble()));
        missedSpots.add(FlSpot(xValue, dayData.missedCallbacks.toDouble()));
      
        double rollingAvg = totalCallsPerDay.isNotEmpty ? totalCallsPerDay.reduce((a, b) => a + b) / 7 : 0;
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
    }

  void _processDailyCycleData(QuerySnapshot cyclesSnapshot, DateTime startDate, DateTime endDate) {
    // Create map of dates with zero counts
    final Map<String, DailyCallData> dataByDate = {};
    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      final dateKey = DateFormat('yyyy-MM-dd').format(currentDate);
      dataByDate[dateKey] = DailyCallData(
        date: currentDate,
        dateKey: dateKey,
      );
      currentDate = currentDate.add(const Duration(days: 1));
    }

    int totalEvents = 0;
    for (var cycleDoc in cyclesSnapshot.docs) {
      final cycleData = cycleDoc.data() as Map<String, dynamic>;

      // Get cycle timestamp
      final startedAtClient = cycleData['started_at_client'] as Timestamp?;
      final startedAtServer = cycleData['started_at_server'] as Timestamp?;
      final cycleTimestamp = startedAtClient ?? startedAtServer;

      if (cycleTimestamp == null) continue;

      final cycleTime = cycleTimestamp.toDate();

      // Check if cycle is within date range
      if (cycleTime.isBefore(startDate) || cycleTime.isAfter(endDate)) {
        continue;
      }

      final dateKey = DateFormat('yyyy-MM-dd').format(cycleTime);
      if (!dataByDate.containsKey(dateKey)) continue;

      // Get stats from cycle document
      final stats = cycleData['stats'];
      if (stats is Map<String, dynamic>) {
        final outgoing = _parseInt(stats['outgoing']);
        final cancelled = _parseInt(stats['cancelled']);
        final missed = _parseInt(stats['missed']);

        // outgoing = successful calls
        dataByDate[dateKey]!.successfulCalls += outgoing;
        // cancelled = failed calls (no answer, hung up, etc)
        dataByDate[dateKey]!.failedCalls += cancelled;
        // missed = missed/no answer
        dataByDate[dateKey]!.missedCallbacks += missed;

        totalEvents += (outgoing + cancelled + missed);
      }
    }

    print('✅ Processed $totalEvents total call events');

    // Create chart data spots
    final List<FlSpot> successfulSpots = [];
    final List<FlSpot> failedSpots = [];
    final List<FlSpot> missedSpots = [];
    final List<FlSpot> rollingAverageSpots = [];

    final sortedDates = dataByDate.keys.toList()..sort();
    final List<double> totalCallsPerDay = [];

    for (int i = 0; i < sortedDates.length; i++) {
      final dateKey = sortedDates[i];
      final dayData = dataByDate[dateKey]!;
      final xValue = i.toDouble();

      successfulSpots.add(FlSpot(xValue, dayData.successfulCalls.toDouble()));
      failedSpots.add(FlSpot(xValue, dayData.failedCalls.toDouble()));
      missedSpots.add(FlSpot(xValue, dayData.missedCallbacks.toDouble()));
      totalCallsPerDay.add((dayData.successfulCalls + dayData.failedCalls + dayData.missedCallbacks).toDouble());
    }

    // Calculate rolling average
    if (totalCallsPerDay.isNotEmpty) {
      double avg = totalCallsPerDay.reduce((a, b) => a + b) / totalCallsPerDay.length;
      for (int i = 0; i < sortedDates.length; i++) {
        rollingAverageSpots.add(FlSpot(i.toDouble(), avg));
      }
    }

    if (mounted) {
      setState(() {
        _callDataByDate = dataByDate;
        _successfulSpots = successfulSpots;
        _failedSpots = failedSpots;
        _missedSpots = missedSpots;
        _rollingAverageSpots = rollingAverageSpots;
        _isLoading = false;
      });
    }
  }

  void _processWeeklyData(QuerySnapshot querySnapshot, DateTime startDate, DateTime endDate, Set<String> listPhoneNumbers) {
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
        
        // Apply list filter if specified
        if (widget.listFilter != null && listPhoneNumbers.isNotEmpty) {
          final address = data['address'] as String? ?? '';
          final normalizedAddress = _normalizePhoneNumber(address);
          if (!listPhoneNumbers.contains(normalizedAddress)) {
            continue;
          }
        }
        
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        
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

        // Categorize calls
        if (callType.toLowerCase() == 'missed') {
          dataByWeekday[weekday]!.missedCallbacks++;
        } else if (callType.toLowerCase() == 'incoming' && !answered) {
          dataByWeekday[weekday]!.missedCallbacks++;
        } else if (answered || duration > 0) {
          dataByWeekday[weekday]!.successfulCalls++;
        } else {
          dataByWeekday[weekday]!.failedCalls++;
        }
      } catch (e) {
        print('Error parsing call record: $e');
      }
    }

    print('Records processed: $recordsInRange');

    // Create chart data spots
    final List<FlSpot> successfulSpots = [];
    final List<FlSpot> failedSpots = [];
    final List<FlSpot> missedSpots = [];
    final List<FlSpot> rollingAverageSpots = [];

    final List<double> totalCallsPerDay = [];
    for (int i = 1; i <= 7; i++) {
      final dayData = dataByWeekday[i]!;
      totalCallsPerDay.add((dayData.successfulCalls + dayData.failedCalls + dayData.missedCallbacks).toDouble());
    }

    for (int i = 1; i <= 7; i++) {
      final dayData = dataByWeekday[i]!;
      final xValue = (i - 1).toDouble();
      
      successfulSpots.add(FlSpot(xValue, dayData.successfulCalls.toDouble()));
      failedSpots.add(FlSpot(xValue, dayData.failedCalls.toDouble()));
      missedSpots.add(FlSpot(xValue, dayData.missedCallbacks.toDouble()));
      
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
  }

  void _processDailyData(QuerySnapshot querySnapshot, DateTime startDate, DateTime endDate, Set<String> listPhoneNumbers) {
    // Create map of dates with zero counts
    final Map<String, DailyCallData> dataByDate = {};
    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      final dateKey = DateFormat('yyyy-MM-dd').format(currentDate);
      dataByDate[dateKey] = DailyCallData(
        date: currentDate,
        dateKey: dateKey,
      );
      currentDate = currentDate.add(const Duration(days: 1));
    }

    // Aggregate call data by date
    for (var doc in querySnapshot.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        final dateKey = DateFormat('yyyy-MM-dd').format(timestamp);
        
        if (!dataByDate.containsKey(dateKey)) continue;
        
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

        // Categorize calls
        if (callType.toLowerCase() == 'missed') {
          dataByDate[dateKey]!.missedCallbacks++;
        } else if (callType.toLowerCase() == 'incoming' && !answered) {
          dataByDate[dateKey]!.missedCallbacks++;
        } else if (answered || duration > 0) {
          dataByDate[dateKey]!.successfulCalls++;
        } else {
          dataByDate[dateKey]!.failedCalls++;
        }
      } catch (e) {
        print('Error parsing call record: $e');
      }
    }

    // Create chart data spots
    final List<FlSpot> successfulSpots = [];
    final List<FlSpot> failedSpots = [];
    final List<FlSpot> missedSpots = [];
    final List<FlSpot> rollingAverageSpots = [];

    final sortedDates = dataByDate.keys.toList()..sort();
    final List<double> totalCallsPerDay = [];

    for (int i = 0; i < sortedDates.length; i++) {
      final dateKey = sortedDates[i];
      final dayData = dataByDate[dateKey]!;
      final xValue = i.toDouble();
      
      successfulSpots.add(FlSpot(xValue, dayData.successfulCalls.toDouble()));
      failedSpots.add(FlSpot(xValue, dayData.failedCalls.toDouble()));
      missedSpots.add(FlSpot(xValue, dayData.missedCallbacks.toDouble()));
      totalCallsPerDay.add((dayData.successfulCalls + dayData.failedCalls + dayData.missedCallbacks).toDouble());
    }

    // Calculate rolling average
    if (totalCallsPerDay.isNotEmpty) {
      double avg = totalCallsPerDay.reduce((a, b) => a + b) / totalCallsPerDay.length;
      for (int i = 0; i < sortedDates.length; i++) {
        rollingAverageSpots.add(FlSpot(i.toDouble(), avg));
      }
    }

    if (mounted) {
      setState(() {
        _callDataByDate = dataByDate;
        _successfulSpots = successfulSpots;
        _failedSpots = failedSpots;
        _missedSpots = missedSpots;
        _rollingAverageSpots = rollingAverageSpots;
        _isLoading = false;
      });
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
          
          // Time range selector (only show if not externally controlled)
          if (!isExternallyControlled) 
            Column(
              children: [
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
                const SizedBox(height: 16),
              ],
            ),

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
          else if ((_useWeeklyView && _callDataByWeekday.isEmpty) || (!_useWeeklyView && _callDataByDate.isEmpty) || _getMaxY() == 0)
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
                        interval: _useWeeklyView ? 1 : (_callDataByDate.length > 14 ? 3 : 1),
                        getTitlesWidget: (double value, TitleMeta meta) {
                          if (_useWeeklyView) {
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
                          } else {
                            // Daily view - show dates
                            final sortedDates = _callDataByDate.keys.toList()..sort();
                            final index = value.toInt();
                            if (index >= 0 && index < sortedDates.length) {
                              final dateKey = sortedDates[index];
                              final dayData = _callDataByDate[dateKey];
                              if (dayData != null) {
                                return RotatedBox(
                                  quarterTurns: -1,
                                  child: Text(
                                    DateFormat('M/d').format(dayData.date),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }
                            }
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
                  maxX: _useWeeklyView ? 6 : (_callDataByDate.length - 1).toDouble(),
                  minY: 0,
                  maxY: _getMaxY() + 5,
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => Colors.blueGrey.shade800,
                      tooltipRoundedRadius: 8,
                      tooltipPadding: const EdgeInsets.all(12),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        if (touchedBarSpots.isEmpty) return [];
                        
                        // Get the x value from the first touched spot
                        final xValue = touchedBarSpots.first.x.toInt();
                        
                        // Get data based on view mode
                        String dateLabel;
                        int successful = 0;
                        int failed = 0;
                        int missed = 0;
                        
                        if (_useWeeklyView) {
                          final weekday = xValue + 1;
                          final dayData = _callDataByWeekday[weekday];
                          if (dayData == null) return [];
                          
                          dateLabel = dayData.dayName;
                          successful = dayData.successfulCalls;
                          failed = dayData.failedCalls;
                          missed = dayData.missedCallbacks;
                        } else {
                          final sortedDates = _callDataByDate.keys.toList()..sort();
                          if (xValue >= 0 && xValue < sortedDates.length) {
                            final dateKey = sortedDates[xValue];
                            final dayData = _callDataByDate[dateKey];
                            if (dayData == null) return [];
                            
                            dateLabel = DateFormat('MMM d').format(dayData.date);
                            successful = dayData.successfulCalls;
                            failed = dayData.failedCalls;
                            missed = dayData.missedCallbacks;
                          } else {
                            return [];
                          }
                        }
                        
                        final total = successful + failed + missed;
                        
                        // Return tooltip items for each line that was touched
                        return touchedBarSpots.map((LineBarSpot touchedSpot) {
                          // Only show the comprehensive tooltip once (for the first line)
                          if (touchedSpot.barIndex == 0) {
                            return LineTooltipItem(
                              '$dateLabel\n',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: '✓ Successful: $successful\n',
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                                TextSpan(
                                  text: '✗ Failed: $failed\n',
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                                TextSpan(
                                  text: '◉ Missed: $missed\n',
                                  style: const TextStyle(
                                    color: Colors.orangeAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                                TextSpan(
                                  text: '━━━━━━━━━\n',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 10,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Total: $total',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          } else {
                            // For other lines, return null so they don't show separate tooltips
                            return const LineTooltipItem('', TextStyle());
                          }
                        }).toList();
                      },
                    ),
                    handleBuiltInTouches: true,
                    touchSpotThreshold: 20,
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
          if (!_isLoading && ((_useWeeklyView && _callDataByWeekday.isNotEmpty) || (!_useWeeklyView && _callDataByDate.isNotEmpty)) && _getMaxY() > 0)
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
                  if (_useWeeklyView)
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
                    }).toList()
                  else
                    // Daily view - show all dates
                    ...(() {
                      final sortedDates = _callDataByDate.keys.toList()..sort();
                      return sortedDates.map((dateKey) {
                        final dayData = _callDataByDate[dateKey]!;
                        final total = dayData.successfulCalls + dayData.failedCalls + dayData.missedCallbacks;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 70,
                                child: Text(
                                  DateFormat('MMM d').format(dayData.date),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    _buildStatBadge('S: ${dayData.successfulCalls}', Colors.green),
                                    _buildStatBadge('F: ${dayData.failedCalls}', Colors.red),
                                    _buildStatBadge('M: ${dayData.missedCallbacks}', Colors.orange),
                                    Text(
                                      'Total: $total',
                                      style: TextStyle(
                                        fontSize: 11,
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
                      }).toList();
                    })(),
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
    if (_useWeeklyView) {
      for (var data in _callDataByWeekday.values) {
        final dayMax = (data.successfulCalls + data.failedCalls + data.missedCallbacks).toDouble();
        if (dayMax > max) max = dayMax;
      }
    } else {
      for (var data in _callDataByDate.values) {
        final dayMax = (data.successfulCalls + data.failedCalls + data.missedCallbacks).toDouble();
        if (dayMax > max) max = dayMax;
      }
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

class DailyCallData {
  final DateTime date;
  final String dateKey;
  int successfulCalls = 0;
  int failedCalls = 0;
  int missedCallbacks = 0;

  DailyCallData({
    required this.date,
    required this.dateKey,
  });
}
