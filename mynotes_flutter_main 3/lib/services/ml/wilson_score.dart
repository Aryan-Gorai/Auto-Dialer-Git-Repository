import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

/// STATISTICAL ALGORITHM: Wilson Score Interval
/// 
/// FORMULA: CI = (p + z²/2n ± z√(p(1-p)/n + z²/4n²)) / (1 + z²/n)
/// 
/// WHERE:
///   - p = success rate (proportion of successful/answered calls)
///   - n = sample size (total number of calls)
///   - z = 1.96 for 95% confidence level (z-score from standard normal distribution)
///   - CI = Confidence Interval bounds (lower and upper)
/// 
/// PURPOSE: 
/// Calculates a statistically robust confidence interval for call success rates.
/// Unlike simple percentage calculations, the Wilson Score accounts for:
///   1. Sample size (small samples get wider intervals = less certainty)
///   2. Success rate (extreme values like 0% or 100% get adjusted)
///   3. Statistical confidence (95% confidence = we're 95% sure the true rate is in this range)
/// 
/// WHY IT'S BETTER THAN SIMPLE PERCENTAGES:
///   - If you have 2/2 successful calls (100%), simple math says 100% success
///   - Wilson Score says: "Wait, you only have 2 calls. The true rate is likely 34%-100%"
///   - More calls = narrower interval = more confidence in the success rate
/// 
/// USE CASE:
/// For each contact, calculate how confident we are in their success rate.
/// Helps identify:
///   - High-confidence good leads (high rate, many calls)
///   - Uncertain leads (need more data)
///   - Low-confidence leads (low rate with enough data to be sure)

class WilsonScoreResult {
  final String contactId;
  final String contactName;
  final String phoneNumber;
  final int totalCalls;
  final int successfulCalls;
  final double successRate; // Simple success rate (p)
  final double lowerBound; // Lower confidence interval bound
  final double upperBound; // Upper confidence interval bound
  final double intervalWidth; // Width of confidence interval (uncertainty measure)
  final double confidenceScore; // 0-100, how confident we are (narrower = better)

  WilsonScoreResult({
    required this.contactId,
    required this.contactName,
    required this.phoneNumber,
    required this.totalCalls,
    required this.successfulCalls,
    required this.successRate,
    required this.lowerBound,
    required this.upperBound,
    required this.intervalWidth,
    required this.confidenceScore,
  });
}

class WilsonScoreCalculator {
  // z-score for 95% confidence level (standard normal distribution)
  static const double z95 = 1.96;

  /// Fetches call data for all contacts and calculates Wilson Score intervals
  /// Returns list of contacts sorted by confidence score (most confident first)
  Future<List<WilsonScoreResult>> calculateForAllContacts(String userId) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      // Step 1: Get all contacts from Contact Directories
      QuerySnapshot contactsSnapshot = await firestore
          .collection('Contact Directories')
          .where('user_id', isEqualTo: userId)
          .get();

      // Step 2: Fetch ALL call history for this user once (more efficient)
      QuerySnapshot allCallsSnapshot = await firestore
          .collection('call_history')
          .where('user_id', isEqualTo: userId)
          .get();

      // Step 3: Group calls by normalized phone number
      Map<String, List<Map<String, dynamic>>> callsByPhone = {};
      for (var callDoc in allCallsSnapshot.docs) {
        final callData = callDoc.data() as Map<String, dynamic>;
        final address = callData['address'] as String? ?? '';
        final normalizedAddress = _normalizePhone(address);
        
        if (normalizedAddress.isEmpty) continue;
        
        if (!callsByPhone.containsKey(normalizedAddress)) {
          callsByPhone[normalizedAddress] = [];
        }
        callsByPhone[normalizedAddress]!.add(callData);
      }

      List<WilsonScoreResult> results = [];

      // Step 4: For each contact, get their calls and calculate Wilson Score
      for (var contactDoc in contactsSnapshot.docs) {
        final contactData = contactDoc.data() as Map<String, dynamic>;
        final contactName = contactData['contact_name'] ?? '';
        final phoneNumber = contactData['contact_phone_number'] ?? '';
        final normalizedPhone = contactData['normalized_phone'] ?? '';

        if (normalizedPhone.isEmpty) continue;

        // Get calls for this contact from our grouped map
        final contactCalls = callsByPhone[normalizedPhone] ?? [];

        if (contactCalls.isEmpty) continue;

        int totalCalls = contactCalls.length;
        int successfulCalls = 0;

        // Count successful calls (same logic as other ML algorithms)
        for (var callData in contactCalls) {
          if (_wasCallAnswered(callData)) {
            successfulCalls++;
          }
        }

        // Calculate Wilson Score interval
        final wilsonScore = calculateWilsonScore(
          successfulCalls: successfulCalls,
          totalCalls: totalCalls,
        );

        results.add(WilsonScoreResult(
          contactId: contactDoc.id,
          contactName: contactName.isNotEmpty ? contactName : phoneNumber,
          phoneNumber: phoneNumber,
          totalCalls: totalCalls,
          successfulCalls: successfulCalls,
          successRate: wilsonScore['successRate']!,
          lowerBound: wilsonScore['lowerBound']!,
          upperBound: wilsonScore['upperBound']!,
          intervalWidth: wilsonScore['intervalWidth']!,
          confidenceScore: wilsonScore['confidenceScore']!,
        ));
      }

      // Sort by confidence score (highest first) - these are our most reliable leads
      results.sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));

      return results;
    } catch (e) {
      print('Error calculating Wilson Scores: $e');
      rethrow;
    }
  }

  /// Normalizes a phone number for consistent matching
  /// Uses same logic as Linear Regression: last 9 digits
  String _normalizePhone(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length >= 9) {
      return digitsOnly.substring(digitsOnly.length - 9);
    }
    return digitsOnly;
  }

  /// Calculates the Wilson Score Confidence Interval for a given success rate
  /// 
  /// FORMULA BREAKDOWN:
  /// 1. p̂ = successfulCalls / totalCalls (observed success rate)
  /// 2. Center adjustment = p̂ + z²/(2n)
  /// 3. Margin of error = z * √(p̂(1-p̂)/n + z²/(4n²))
  /// 4. Denominator = 1 + z²/n
  /// 5. Lower bound = (center - margin) / denominator
  /// 6. Upper bound = (center + margin) / denominator
  Map<String, double> calculateWilsonScore({
    required int successfulCalls,
    required int totalCalls,
    double zScore = z95,
  }) {
    if (totalCalls == 0) {
      return {
        'successRate': 0.0,
        'lowerBound': 0.0,
        'upperBound': 0.0,
        'intervalWidth': 0.0,
        'confidenceScore': 0.0,
      };
    }

    // Step 1: Calculate observed success rate (p̂)
    final double p = successfulCalls / totalCalls;
    final double n = totalCalls.toDouble();

    // Step 2: Calculate z² (pre-compute for efficiency)
    final double z2 = zScore * zScore;

    // Step 3: Calculate center adjustment
    // center = p + z²/(2n)
    final double center = p + (z2 / (2 * n));

    // Step 4: Calculate margin of error
    // margin = z * √(p(1-p)/n + z²/(4n²))
    final double sqrtTerm = math.sqrt(
      (p * (1 - p) / n) + (z2 / (4 * n * n))
    );
    final double margin = zScore * sqrtTerm;

    // Step 5: Calculate denominator
    // denominator = 1 + z²/n
    final double denominator = 1 + (z2 / n);

    // Step 6: Calculate confidence interval bounds
    final double lowerBound = ((center - margin) / denominator).clamp(0.0, 1.0);
    final double upperBound = ((center + margin) / denominator).clamp(0.0, 1.0);

    // Step 7: Calculate interval width (measure of uncertainty)
    final double intervalWidth = upperBound - lowerBound;

    // Step 8: Calculate confidence score (0-100)
    // Narrower interval = higher confidence
    // More calls and stable success rates = narrower intervals
    // Inverse of interval width, scaled to 0-100
    final double confidenceScore = ((1 - intervalWidth) * 100).clamp(0.0, 100.0);

    return {
      'successRate': p,
      'lowerBound': lowerBound,
      'upperBound': upperBound,
      'intervalWidth': intervalWidth,
      'confidenceScore': confidenceScore,
    };
  }

  /// Determines if a call was answered (successful)
  /// Uses same logic as other ML algorithms for consistency
  bool _wasCallAnswered(Map<String, dynamic> callData) {
    // Check if call was answered
    final answered = callData['answered'];
    bool isAnswered = false;

    if (answered is bool) {
      isAnswered = answered;
    } else if (answered is int) {
      isAnswered = answered == 1;
    }

    // Also check call_type - "Missed" calls are never successful
    final callType = callData['call_type'] as String?;
    if (callType == 'Missed') {
      return false;
    }

    return isAnswered;
  }

  /// Gets interpretation message for a given confidence score
  static String getConfidenceInterpretation(double confidenceScore) {
    if (confidenceScore >= 90) {
      return 'Very High Confidence';
    } else if (confidenceScore >= 75) {
      return 'High Confidence';
    } else if (confidenceScore >= 60) {
      return 'Moderate Confidence';
    } else if (confidenceScore >= 40) {
      return 'Low Confidence';
    } else {
      return 'Very Low Confidence - Need More Data';
    }
  }

  /// Gets color based on confidence score
  static String getConfidenceColor(double confidenceScore) {
    if (confidenceScore >= 75) {
      return 'green';
    } else if (confidenceScore >= 50) {
      return 'orange';
    } else {
      return 'red';
    }
  }
}
