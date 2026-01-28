import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:intl/intl.dart';

class CallHeatmap extends StatefulWidget {
  final String timeScale; // 'month', 'week', 'day'
  final int maxCallThreshold; // Value that represents the darkest green
  final int timeOffset; // Offset for navigation (0 = current, -1 = previous, 1 = next, etc.)
  final String? contactFilter; // Optional: normalized_phone to filter by specific contact

  const CallHeatmap({
    Key? key,
    required this.timeScale,
    required this.maxCallThreshold,
    required this.timeOffset,
    this.contactFilter,
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
        // Default to month view with offset
        final targetMonth = now.month + widget.timeOffset;
        final targetYear = now.year + (targetMonth - 1) ~/ 12;
        final normalizedMonth = ((targetMonth - 1) % 12) + 1;
        
        startDate = DateTime(targetYear, normalizedMonth, 1);
        endDate = DateTime(targetYear, normalizedMonth + 1, 0);
        daysToShow = endDate.day;
    }
  }

  Future<void> fetchCallData() async {
    setState(() {
      isLoading = true;
    });

    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      // Build base query for contact_notes collection
      Query query = firestore
          .collection('contact_notes')
          .where('user_id', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

      // If contact filter is set, we need to get the phone number from Contact Directories first
      String? phoneNumberToFilter;
      if (widget.contactFilter != null) {
        // Fetch the contact from Contact Directories to get the phone number
        final contactDoc = await firestore
            .collection('Contact Directories')
            .where('user_id', isEqualTo: userId)
            .where('normalized_phone', isEqualTo: widget.contactFilter)
            .limit(1)
            .get();
        
        if (contactDoc.docs.isNotEmpty) {
          phoneNumberToFilter = contactDoc.docs.first['contact_phone_number'] as String?;
        }
      }

      // Execute the query
      QuerySnapshot snapshot = await query.get();

      // Initialize the call data map
      Map<String, int> newCallData = {};
      
      // Process the query results
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Apply contact filter if specified
        if (phoneNumberToFilter != null) {
          final docPhone = data['contact_phone_number'] as String?;
          if (docPhone != phoneNumberToFilter) {
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
      }
      
      setState(() {
        callData = newCallData;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching call data: $e');
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
      // For month and week views, show date
      final date = startDate.add(Duration(days: index));
      return DateFormat('d').format(date);
    }
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
        
        // Heatmap grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.timeScale == 'month' ? 7 : (widget.timeScale == 'week' ? 7 : 6),
              childAspectRatio: 1.0,
              crossAxisSpacing: 4.0,
              mainAxisSpacing: 4.0,
            ),
            itemCount: daysToShow,
            itemBuilder: (context, index) {
              String key;
              if (widget.timeScale == 'day') {
                key = index.toString();
              } else {
                final date = startDate.add(Duration(days: index));
                key = DateFormat('yyyy-MM-dd').format(date);
              }
              
              final callCount = callData[key] ?? 0;
              
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
                        getCellLabel(index),
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
          ),
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
