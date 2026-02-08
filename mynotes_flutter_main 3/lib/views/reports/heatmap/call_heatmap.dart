// GitHub-style call activity heatmap. Each cell represents a day, coloured
// from white (no calls) to dark green (many calls) based on how many calls
// were made. Supports multiple time scales (week, month, last 7 days, custom)
// and can filter by contact or list. The max threshold controls the colour scale.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:intl/intl.dart';

class CallHeatmap extends StatefulWidget {
  final String timeScale; // 'month', 'week', 'day', 'custom', 'last7days', 'currentWeek', 'last30days'
  final int maxCallThreshold; // Value that represents the darkest green
  final int timeOffset; // Offset for navigation (0 = current, -1 = previous, 1 = next, etc.)
  final String? contactFilter; // Optional: normalized_phone to filter by specific contact
  final String? listFilter; // Optional: list_name to filter by specific list
  final DateTime? customStartDate; // For custom date range
  final DateTime? customEndDate; // For custom date range
  final String? targetUserId; // If set, view this user's data instead of current user

  const CallHeatmap({
    Key? key,
    required this.timeScale,
    required this.maxCallThreshold,
    required this.timeOffset,
    this.contactFilter,
    this.listFilter,
    this.customStartDate,
    this.customEndDate,
    this.targetUserId,
  }) : super(key: key);

  @override
  State<CallHeatmap> createState() => _CallHeatmapState();
}

class _CallHeatmapState extends State<CallHeatmap> {
  bool isLoading = true;
  Map<String, int> callData = {}; // Key: date string, Value: call count
  late DateTime startDate;
  late DateTime endDate;
  late int daysToShow;
  
  String get userId => widget.targetUserId ?? AuthService.firebase().currentUser!.id;

  @override
  void initState() {
    super.initState();
    _setupDateRange();
    fetchCallData();
  }

  @override
  void didUpdateWidget(CallHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Always refresh data when the widget is updated
    _setupDateRange();
    fetchCallData();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when dependencies change (e.g., when returning to this screen)
    fetchCallData();
  }

  // Configures the start/end dates and daysToShow based on the
  // selected time scale (custom, last7days, last30days, allTime).
  void _setupDateRange() {
    final now = DateTime.now();
    
    switch (widget.timeScale) {
      case 'custom':
        // Use custom date range if provided
        if (widget.customStartDate != null && widget.customEndDate != null) {
          startDate = widget.customStartDate!;
          endDate = widget.customEndDate!;
          // Calculate the number of days between start and end
          daysToShow = endDate.difference(startDate).inDays + 1;
        } else {
          // Fallback to last 30 days if custom dates not provided
          startDate = now.subtract(const Duration(days: 30));
          endDate = now;
          daysToShow = 30;
        }
        break;
        
      case 'last7days':
        startDate = now.subtract(const Duration(days: 7));
        endDate = now;
        daysToShow = 7;
        break;
        
      case 'currentWeek':
        // Calculate current week (Sunday to Saturday)
        final baseWeekStart = now.subtract(Duration(days: now.weekday % 7));
        startDate = baseWeekStart.add(Duration(days: 7 * widget.timeOffset));
        endDate = startDate.add(const Duration(days: 6));
        daysToShow = 7;
        break;
        
      case 'last30days':
        startDate = now.subtract(const Duration(days: 30));
        endDate = now;
        daysToShow = 30;
        break;
        
      case 'month':
        // Calculate month with offset
        final targetMonth = now.month + widget.timeOffset;
        final targetYear = now.year + (targetMonth - 1) ~/ 12;
        final normalizedMonth = ((targetMonth - 1) % 12) + 1;
        
        startDate = DateTime(targetYear, normalizedMonth, 1);
        // Last day of the target month
        endDate = DateTime(targetYear, normalizedMonth + 1, 0);
        daysToShow = endDate.day;
        break;
        
      case 'week':
        // Calculate week with offset
        final baseWeekStart = now.subtract(Duration(days: now.weekday % 7));
        startDate = baseWeekStart.add(Duration(days: 7 * widget.timeOffset));
        endDate = startDate.add(const Duration(days: 6));
        daysToShow = 7;
        break;
        
      case 'day':
        // Calculate day with offset
        final targetDay = now.add(Duration(days: widget.timeOffset));
        startDate = DateTime(targetDay.year, targetDay.month, targetDay.day);
        endDate = startDate.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
        daysToShow = 24; // 24 hours
        break;
        
      default:
        // Default to last 7 days
        startDate = now.subtract(const Duration(days: 7));
        endDate = now;
        daysToShow = 7;
    }
  }

  // Helper function to normalize phone numbers for comparison
  String _normalizePhoneNumber(String phone) {
    // Remove all non-digit characters
    return phone.replaceAll(RegExp(r'[^\d]'), '');
  }

  // Main fetch entry point — routes to the appropriate data source
  // depending on whether a list filter or contact filter is active.
  Future<void> fetchCallData() async {
    setState(() {
      isLoading = true;
    });

    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      print('📊 Fetching call history data...');
      print('Time range: $startDate to $endDate');
      print('Contact filter: ${widget.contactFilter}');
      print('List filter: ${widget.listFilter}');

      // If list filter is set, use list_cycles/cycle_events data
      if (widget.listFilter != null && widget.listFilter!.isNotEmpty) {
        print('🔍 Using list_cycles data for list: ${widget.listFilter}');
        await _fetchFromCycleEvents(firestore);
        return;
      }

      // If only contact filter is set (no list filter), use cycle_events across all lists
      if (widget.contactFilter != null && widget.contactFilter!.isNotEmpty) {
        print('🔍 Using cycle_events data for contact: ${widget.contactFilter}');
        await _fetchFromAllCycleEvents(firestore);
        return;
      }

      // Otherwise, use the original call_history logic (no filters)
      print('🔍 Using call_history data (no filters)');
      await _fetchFromCallHistory(firestore);
    } catch (e) {
      print('❌ Error fetching call data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Queries list_cycles for a specific list, then reads each cycle's
  // embedded cycle_events to build the heatmap day-by-day call counts.
  Future<void> _fetchFromCycleEvents(FirebaseFirestore firestore) async {
    print('📊 Fetching from list_cycles for list: ${widget.listFilter}');
    print('📅 Date range: $startDate to $endDate');
    print('👤 Contact filter: ${widget.contactFilter}');

    // Query list_cycles for the specified list
    Query cyclesQuery = firestore
        .collection('list_cycles')
        .where('user_id', isEqualTo: userId)
        .where('list_name', isEqualTo: widget.listFilter);

    // Fetch all matching cycles
    QuerySnapshot cyclesSnapshot = await cyclesQuery.get();
    print('📂 Found ${cyclesSnapshot.docs.length} cycles for list "${widget.listFilter}"');

    Map<String, int> newCallData = {};
    int processedEvents = 0;
    int filteredEvents = 0;
    int totalOutgoingFromStats = 0;

    // Iterate through each cycle
    for (var cycleDoc in cyclesSnapshot.docs) {
      final cycleId = cycleDoc.id;
      final cycleData = cycleDoc.data() as Map<String, dynamic>;
      
      // Get the cycle start time to determine which day/hour it belongs to
      final startedAtClient = cycleData['started_at_client'] as Timestamp?;
      final startedAtServer = cycleData['started_at_server'] as Timestamp?;
      final cycleTimestamp = startedAtClient ?? startedAtServer;
      
      if (cycleTimestamp == null) {
        print('⚠️ Cycle $cycleId has no timestamp, skipping');
        continue;
      }
      
      final cycleTime = cycleTimestamp.toDate();
      
      // Check if cycle is within date range
      if (cycleTime.isBefore(startDate) || cycleTime.isAfter(endDate)) {
        print('⏭️ Cycle $cycleId outside date range (${cycleTime}), skipping');
        continue;
      }

      // If NO contact filter is set, use stats.outgoing for efficiency
      if (widget.contactFilter == null || widget.contactFilter!.isEmpty) {
        // Get stats.outgoing count from this cycle
        final stats = cycleData['stats'] as Map<String, dynamic>?;
        final outgoingCount = stats?['outgoing'] as int? ?? 0;
        
        print('📈 Cycle $cycleId has $outgoingCount outgoing calls (from stats)');
        totalOutgoingFromStats += outgoingCount;
        
        // Generate key based on time scale
        String key;
        if (widget.timeScale == 'day') {
          key = cycleTime.hour.toString();
        } else {
          key = DateFormat('yyyy-MM-dd').format(cycleTime);
        }
        
        // Add outgoing count to the appropriate time bucket
        newCallData[key] = (newCallData[key] ?? 0) + outgoingCount;
        processedEvents += outgoingCount;
      } else {
        // If contact filter IS set, we need to check individual cycle_events
        print('👤 Contact filter active, fetching cycle_events for cycle $cycleId');
        
        QuerySnapshot eventsSnapshot = await firestore
            .collection('list_cycles')
            .doc(cycleId)
            .collection('cycle_events')
            .get();

        print('   Found ${eventsSnapshot.docs.length} events in this cycle');

        // Process each event
        for (var eventDoc in eventsSnapshot.docs) {
          final eventData = eventDoc.data() as Map<String, dynamic>;

          // Get timestamp from dial_pressed_at_client
          final dialPressedTimestamp = eventData['dial_pressed_at_client'] as Timestamp?;
          if (dialPressedTimestamp == null) {
            continue; // Skip if no timestamp
          }

          final eventTime = dialPressedTimestamp.toDate();

          // Check if event is within date range
          if (eventTime.isBefore(startDate) || eventTime.isAfter(endDate)) {
            filteredEvents++;
            continue;
          }

          // Apply contact filter
          final normalizedPhone = eventData['normalized_phone'] as String?;
          if (normalizedPhone != widget.contactFilter) {
            filteredEvents++;
            continue;
          }

          print('   ✓ Event matches contact filter: ${eventData['contact_name']} ($normalizedPhone)');

          // Generate key based on time scale
          String key;
          if (widget.timeScale == 'day') {
            key = eventTime.hour.toString();
          } else {
            key = DateFormat('yyyy-MM-dd').format(eventTime);
          }

          // Increment call count
          newCallData[key] = (newCallData[key] ?? 0) + 1;
          processedEvents++;
        }
      }
    }

    if (widget.contactFilter == null || widget.contactFilter!.isEmpty) {
      print('✅ Processed ${cyclesSnapshot.docs.length} cycles with total $totalOutgoingFromStats outgoing calls');
    } else {
      print('✅ Processed $processedEvents matching events, filtered out $filteredEvents');
    }
    print('📊 Final heatmap data: $newCallData');

    setState(() {
      callData = newCallData;
      isLoading = false;
    });
  }

  // Fetch data from all cycle_events (when only contact filter is set, no list filter)
  Future<void> _fetchFromAllCycleEvents(FirebaseFirestore firestore) async {
    print('📊 Fetching from all list_cycles for contact: ${widget.contactFilter}');
    print('📅 Date range: $startDate to $endDate');

    // Query all list_cycles for this user
    Query cyclesQuery = firestore
        .collection('list_cycles')
        .where('user_id', isEqualTo: userId);

    // Fetch all cycles
    QuerySnapshot cyclesSnapshot = await cyclesQuery.get();
    print('📂 Found ${cyclesSnapshot.docs.length} total cycles');

    Map<String, int> newCallData = {};
    int processedEvents = 0;
    int filteredEvents = 0;

    // Iterate through each cycle
    for (var cycleDoc in cyclesSnapshot.docs) {
      final cycleId = cycleDoc.id;
      
      // Fetch cycle_events subcollection
      QuerySnapshot eventsSnapshot = await firestore
          .collection('list_cycles')
          .doc(cycleId)
          .collection('cycle_events')
          .get();

      // Process each event
      for (var eventDoc in eventsSnapshot.docs) {
        final eventData = eventDoc.data() as Map<String, dynamic>;

        // Get timestamp from dial_pressed_at_client
        final dialPressedTimestamp = eventData['dial_pressed_at_client'] as Timestamp?;
        if (dialPressedTimestamp == null) {
          continue; // Skip if no timestamp
        }

        final eventTime = dialPressedTimestamp.toDate();

        // Check if event is within date range
        if (eventTime.isBefore(startDate) || eventTime.isAfter(endDate)) {
          filteredEvents++;
          continue;
        }

        // Apply contact filter
        final normalizedPhone = eventData['normalized_phone'] as String?;
        if (normalizedPhone != widget.contactFilter) {
          filteredEvents++;
          continue;
        }

        print('   ✓ Event matches contact: ${eventData['contact_name']} ($normalizedPhone)');

        // Generate key based on time scale
        String key;
        if (widget.timeScale == 'day') {
          key = eventTime.hour.toString();
        } else {
          key = DateFormat('yyyy-MM-dd').format(eventTime);
        }

        // Increment call count
        newCallData[key] = (newCallData[key] ?? 0) + 1;
        processedEvents++;
      }
    }

    print('✅ Processed $processedEvents matching events, filtered out $filteredEvents');
    print('📊 Final heatmap data: $newCallData');

    setState(() {
      callData = newCallData;
      isLoading = false;
    });
  }

  // Falls back to the raw call_history collection when no list is
  // filtered. Aggregates timestamps into per-day counts for the heatmap.
  Future<void> _fetchFromCallHistory(FirebaseFirestore firestore) async {
    // Build set of normalized phones to filter by (for contact filter)
    Set<String>? allowedPhones;

    // If contact filter is set
    if (widget.contactFilter != null) {
      allowedPhones = {widget.contactFilter!};
      print('Filtering by normalized phone: ${widget.contactFilter}');
    }
      
    // Build base query for call_history collection
    Query query = firestore
        .collection('call_history')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

    // Execute the query
    QuerySnapshot snapshot = await query.get();
    print('Found ${snapshot.docs.length} call records in call_history');

    // Initialize the call data map
    Map<String, int> newCallData = {};
    int processedCalls = 0;
    int filteredCalls = 0;
      
    // Process the query results
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
        
      // Get the address (phone number) from call_history
      final address = data['address'] as String?;
      if (address == null || address.isEmpty) {
        continue; // Skip if no phone number
      }
        
      // Apply filters if specified
      if (allowedPhones != null) {
        // Normalize the address from call_history for comparison
        final normalizedAddress = _normalizePhoneNumber(address);
          
        if (!allowedPhones.contains(normalizedAddress)) {
          filteredCalls++;
          continue; // Skip this record if it doesn't match the filters
        }
      }
        
      final timestamp = (data['timestamp'] as Timestamp).toDate();
        
      String key;
      if (widget.timeScale == 'day') {
        // For day view, use hour as key
        key = timestamp.hour.toString();
      } else {
        // For month and week views, use date as key
        key = DateFormat('yyyy-MM-dd').format(timestamp);
      }
        
      // Increment the call count for this key
      newCallData[key] = (newCallData[key] ?? 0) + 1;
      processedCalls++;
    }
      
    print('✅ Processed $processedCalls calls, filtered out $filteredCalls');
    print('Heatmap data: $newCallData');
      
    setState(() {
      callData = newCallData;
      isLoading = false;
    });
  }

  // Get color based on call count and threshold
  Color getHeatmapColor(int callCount) {
    if (callCount == 0) {
      return Colors.grey[300]!;
    }
    
    // Calculate opacity based on call count and threshold
    final double opacity = callCount / widget.maxCallThreshold;
    final double clampedOpacity = opacity.clamp(0.1, 1.0);
    
    // Use green with varying opacity
    return Color.fromRGBO(0, 128, 0, clampedOpacity);
  }

  // Get label for a cell based on time scale
  String getCellLabel(int index) {
    if (widget.timeScale == 'day') {
      // For day view, show hour
      return '$index:00';
    } else {
      // For month and week views, show dateday' ? 6 : 7
      final date = startDate.add(Duration(days: index));
      return DateFormat('d').format(date);
    }
  }

  // Build heatmap with month separators for multi-month ranges
  Widget _buildHeatmapContent() {
    if (widget.timeScale == 'day') {
      // For day view, use simple grid for hours
      return GridView.builder(
        padding: const EdgeInsets.all(8.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          childAspectRatio: 1.0,
          crossAxisSpacing: 4.0,
          mainAxisSpacing: 4.0,
        ),
        itemCount: daysToShow,
        itemBuilder: (context, index) {
          final callCount = callData[index.toString()] ?? 0;
          
          return Container(
            decoration: BoxDecoration(
              color: getHeatmapColor(callCount),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    callCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Text(
                    '$index:00',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    // For date-based views, group by month
    List<Widget> monthSections = [];
    DateTime currentDate = startDate;
    int dayIndex = 0;

    while (dayIndex < daysToShow) {
      // Get the current month and year
      int currentMonth = currentDate.month;
      int currentYear = currentDate.year;
      String monthLabel = DateFormat('MMMM yyyy').format(currentDate);

      // Collect all days in this month
      List<Widget> monthDays = [];
      
      while (dayIndex < daysToShow && 
             currentDate.month == currentMonth && 
             currentDate.year == currentYear) {
        final String key = DateFormat('yyyy-MM-dd').format(currentDate);
        final callCount = callData[key] ?? 0;
        
        monthDays.add(
          Container(
            decoration: BoxDecoration(
              color: getHeatmapColor(callCount),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    callCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Text(
                    DateFormat('d').format(currentDate),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        
        currentDate = currentDate.add(const Duration(days: 1));
        dayIndex++;
      }

      // Add month section with label and grid
      monthSections.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 8.0, bottom: 4.0),
              child: Text(
                monthLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 7,
                childAspectRatio: 1.0,
                crossAxisSpacing: 4.0,
                mainAxisSpacing: 4.0,
                children: monthDays,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: monthSections,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Title with time range
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            _getHeatmapTitle(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        // Heatmap content
        Expanded(
          child: _buildHeatmapContent(),
        ),
        
        // Legend
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 20,
                height: 20,
                color: Colors.grey[300]!,
              ),
              const SizedBox(width: 4),
              const Text('None'),
              const SizedBox(width: 16),
              Container(
                width: 20,
                height: 20,
                color: Color.fromRGBO(0, 128, 0, 0.5),
              ),
              const SizedBox(width: 4),
              const Text('Medium'),
              const SizedBox(width: 16),
              Container(
                width: 20,
                height: 20,
                color: Color.fromRGBO(0, 128, 0, 1.0),
              ),
              const SizedBox(width: 4),
              const Text('Many'),
            ],
          ),
        ),
      ],
    );
  }

  String _getHeatmapTitle() {
    switch (widget.timeScale) {
      case 'month':
        return 'Calls in ${DateFormat('MMMM yyyy').format(startDate)}';
      case 'week':
        return 'Calls from ${DateFormat('MMM d').format(startDate)} to ${DateFormat('MMM d').format(endDate)}';
      case 'day':
        return 'Calls on ${DateFormat('EEEE, MMM d').format(startDate)}';
      default:
        return 'Call Heatmap';
    }
  }
}
