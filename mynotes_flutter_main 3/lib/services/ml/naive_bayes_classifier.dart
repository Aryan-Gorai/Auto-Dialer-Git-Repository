import 'package:cloud_firestore/cloud_firestore.dart';

class CallPrediction {
  final int dayOfWeek; // 1 = Monday, 7 = Sunday
  final int hour; // 0-23
  final double probability;
  final int totalCalls;
  final int answeredCalls;

  CallPrediction({
    required this.dayOfWeek,
    required this.hour,
    required this.probability,
    required this.totalCalls,
    required this.answeredCalls,
  });

  String get dayName {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[dayOfWeek - 1];
  }

  String get timeRange {
    final endHour = (hour + 1) % 24;
    return '${hour.toString().padLeft(2, '0')}:00 - ${endHour.toString().padLeft(2, '0')}:00';
  }

  double get successRate => totalCalls > 0 ? (answeredCalls / totalCalls) : 0.0;
}

class NaiveBayesCallPredictor {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches call history for a specific contact
  Future<List<Map<String, dynamic>>> _fetchCallHistory(String userId, String phoneNumber) async {
    try {
      // Normalize phone number for matching
      final normalizedPhone = _normalizePhone(phoneNumber);
      
      final snapshot = await _firestore
          .collection('call_history')
          .where('user_id', isEqualTo: userId)
          .get();

      List<Map<String, dynamic>> callData = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final address = data['address'] as String? ?? '';
        final normalizedAddress = _normalizePhone(address);
        
        // Match by normalized phone number
        if (normalizedAddress == normalizedPhone) {
          final timestamp = data['timestamp'] as Timestamp?;
          if (timestamp == null) continue;
          
          final dateTime = timestamp.toDate();
          final answered = _wasCallAnswered(data);
          
          callData.add({
            'day_of_week': dateTime.weekday, // 1 = Monday, 7 = Sunday
            'hour': dateTime.hour,
            'answered': answered,
            'duration': (data['duration'] as num?)?.toDouble() ?? 0.0,
            'call_type': data['call_type'] as String? ?? '',
          });
        }
      }
      
      return callData;
    } catch (e) {
      print('Error fetching call history: $e');
      return [];
    }
  }

  /// Determines if a call was answered based on call_history data
  /// Uses the same logic as Call History page
  bool _wasCallAnswered(Map<String, dynamic> callData) {
    // Get the answered field
    bool answered;
    if (callData['answered'] is bool) {
      answered = callData['answered'] as bool;
    } else if (callData['answered'] is int) {
      answered = (callData['answered'] as int) == 1;
    } else {
      answered = false; // Default value
    }
    
    // Get call type
    final callType = (callData['call_type'] as String? ?? '').trim();
    
    // Logic matching Call History page:
    // - "Missed" calls are never successful
    // - "Outgoing" calls are successful if answered=true
    // - "Incoming" calls are successful if answered=true
    if (callType == 'Missed') {
      return false;
    }
    
    return answered;
  }

  String _normalizePhone(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length >= 9) {
      return digitsOnly.substring(digitsOnly.length - 9);
    }
    return digitsOnly;
  }

  /// Calculate probability using Naive Bayes
  /// P(answered | day, hour) = P(day, hour | answered) × P(answered) / P(day, hour)
  Future<List<CallPrediction>> predictBestTimes(String userId, String phoneNumber) async {
    final callHistory = await _fetchCallHistory(userId, phoneNumber);
    
    if (callHistory.isEmpty) {
      return [];
    }

    // Count occurrences for each day-hour combination
    Map<String, Map<String, int>> stats = {};
    
    for (var call in callHistory) {
      final day = call['day_of_week'] as int;
      final hour = call['hour'] as int;
      final answered = call['answered'] as bool;
      final key = '$day-$hour';
      
      if (!stats.containsKey(key)) {
        stats[key] = {'total': 0, 'answered': 0};
      }
      
      stats[key]!['total'] = stats[key]!['total']! + 1;
      if (answered) {
        stats[key]!['answered'] = stats[key]!['answered']! + 1;
      }
    }

    // Calculate probabilities for each time slot
    List<CallPrediction> predictions = [];
    
    stats.forEach((key, counts) {
      final parts = key.split('-');
      final day = int.parse(parts[0]);
      final hour = int.parse(parts[1]);
      final total = counts['total']!;
      final answered = counts['answered']!;
      
      // Apply Naive Bayes with Laplace smoothing (add-1 smoothing)
      // P(answered | day, hour) ≈ (answered + 1) / (total + 2)
      final probability = (answered + 1) / (total + 2);
      
      predictions.add(CallPrediction(
        dayOfWeek: day,
        hour: hour,
        probability: probability,
        totalCalls: total,
        answeredCalls: answered,
      ));
    });

    // Sort by probability (highest first)
    predictions.sort((a, b) => b.probability.compareTo(a.probability));
    
    return predictions;
  }

  /// Get current time recommendation
  Future<Map<String, dynamic>> getCurrentTimeRecommendation(String userId, String phoneNumber) async {
    final predictions = await predictBestTimes(userId, phoneNumber);
    
    if (predictions.isEmpty) {
      return {
        'should_call_now': false,
        'reason': 'No historical data available',
        'confidence': 0.0,
      };
    }

    final now = DateTime.now();
    final currentDay = now.weekday;
    final currentHour = now.hour;

    // Find prediction for current time slot
    final currentPrediction = predictions.firstWhere(
      (p) => p.dayOfWeek == currentDay && p.hour == currentHour,
      orElse: () => CallPrediction(
        dayOfWeek: currentDay,
        hour: currentHour,
        probability: 0.0,
        totalCalls: 0,
        answeredCalls: 0,
      ),
    );

    // Calculate average probability to compare against
    final avgProbability = predictions.isEmpty 
        ? 0.0 
        : predictions.map((p) => p.probability).reduce((a, b) => a + b) / predictions.length;

    final isGoodTime = currentPrediction.probability >= avgProbability;

    return {
      'should_call_now': isGoodTime,
      'current_probability': currentPrediction.probability,
      'average_probability': avgProbability,
      'confidence': currentPrediction.probability,
      'reason': isGoodTime 
          ? 'Good time to call based on history'
          : 'Not the best time according to past data',
      'total_calls_this_slot': currentPrediction.totalCalls,
      'answered_calls_this_slot': currentPrediction.answeredCalls,
    };
  }

  /// Get top N best times to call
  List<CallPrediction> getTopPredictions(List<CallPrediction> predictions, {int topN = 5}) {
    return predictions.take(topN).toList();
  }

  /// Get predictions grouped by day
  Map<int, List<CallPrediction>> getPredictionsByDay(List<CallPrediction> predictions) {
    Map<int, List<CallPrediction>> byDay = {};
    
    for (var prediction in predictions) {
      if (!byDay.containsKey(prediction.dayOfWeek)) {
        byDay[prediction.dayOfWeek] = [];
      }
      byDay[prediction.dayOfWeek]!.add(prediction);
    }
    
    // Sort each day's predictions by probability
    byDay.forEach((day, preds) {
      preds.sort((a, b) => b.probability.compareTo(a.probability));
    });
    
    return byDay;
  }
}
