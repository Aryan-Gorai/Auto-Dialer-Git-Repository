import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:intl/intl.dart';

class CallHeatmap extends StatefulWidget {
  final String timeScale; // 'month', 'week', 'day', 'custom', 'last7days', 'currentWeek', 'last30days'
  final int maxCallThreshold; // Value that represents the darkest green
  final int timeOffset; // Offset for navigation (0 = current, -1 = previous, 1 = next, etc.)
  final String? contactFilter; // Optional: normalized_phone to filter by specific contact
  final DateTime? customStartDate; // For custom date range
  final DateTime? customEndDate; // For custom date range

  const CallHeatmap({
    Key? key,
    required this.timeScale,
    required this.maxCallThreshold,
    required this.timeOffset,
    this.contactFilter,
    this.customStartDate,
    this.customEndDate,
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
  
  String get userId => AuthService.firebase().currentUser!.id;

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

  Future<void> fetchCallData() async {
    setState(() {
      isLoading = true;
    });

    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      print('📊 Fetching call history data...');
      print('Time range: ${startDate} to ${endDate}');
      print('Contact filter: ${widget.contactFilter}');
      
      // Build base query for call_history collection
      // Note: call_history may not have user_id, so we fetch all and filter by timestamp
      Query query = firestore
          .collection('call_history')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

      // Execute the query
      QuerySnapshot snapshot = await query.get();
      print('Found ${snapshot.docs.length} call records in call_history');

      // If contact filter is set, get the normalized phone to match against
      String? normalizedFilterPhone;
      if (widget.contactFilter != null) {
        // The contactFilter is already the normalized_phone from Contact Directories
        normalizedFilterPhone = widget.contactFilter;
        print('Filtering by normalized phone: $normalizedFilterPhone');
      }

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
        
        // Apply contact filter if specified
        if (normalizedFilterPhone != null) {
          // Normalize the address from call_history for comparison
          final normalizedAddress = _normalizePhoneNumber(address);
          
          if (normalizedAddress != normalizedFilterPhone) {
            filteredCalls++;
            continue; // Skip this record if it doesn't match the filtered contact
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
    } catch (e) {
      print('❌ Error fetching call data: $e');
      setState(() {
        isLoading = false;
      });
    }
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
