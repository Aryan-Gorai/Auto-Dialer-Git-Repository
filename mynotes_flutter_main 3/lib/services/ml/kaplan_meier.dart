import 'package:cloud_firestore/cloud_firestore.dart';

/// STATISTICAL ALGORITHM: Kaplan-Meier Estimator (Survival Analysis)
/// 
/// FORMULA: S(t) = Π(1 - dᵢ/nᵢ) for all i where tᵢ ≤ t
/// 
/// WHERE:
///   - S(t) = Survival probability at time t (probability of NOT converting by time t)
///   - dᵢ = Number of events (conversions) at time tᵢ
///   - nᵢ = Number of subjects "at risk" (not yet converted) at time tᵢ
///   - Π = Product symbol (multiply all terms together)
/// 
/// PURPOSE:
/// Predicts how long it takes for leads to convert (first successful call).
/// Answers questions like:
///   - "What's the probability a lead will convert within 7 days?"
///   - "What's the median time until first successful call?"
///   - "How does conversion probability change over time?"
/// 
/// KEY CONCEPTS:
/// 1. EVENT: First successful/answered call from a lead
/// 2. TIME-TO-EVENT: Days from first contact until first successful call
/// 3. CENSORED DATA: Leads that haven't converted yet (we don't know their final conversion time)
/// 4. SURVIVAL FUNCTION: Probability of remaining unconverted at each time point
/// 
/// EXAMPLE:
/// Day 1: 100 leads, 10 convert → S(1) = (1 - 10/100) = 0.90 (90% haven't converted)
/// Day 2: 90 leads, 5 convert → S(2) = 0.90 × (1 - 5/90) = 0.85 (85% haven't converted)
/// Day 3: 85 leads, 15 convert → S(3) = 0.85 × (1 - 15/85) = 0.70 (70% haven't converted)
/// 
/// CONVERSION PROBABILITY = 1 - S(t)
/// So at Day 3, conversion probability = 1 - 0.70 = 0.30 (30% have converted)

class SurvivalDataPoint {
  final int timeInDays; // Time from first contact
  final int atRisk; // Number of leads still at risk (not converted yet)
  final int events; // Number of conversions at this time point
  final double survivalProbability; // S(t) - probability of NOT converting by this time
  final double conversionProbability; // 1 - S(t) - probability of converting by this time

  SurvivalDataPoint({
    required this.timeInDays,
    required this.atRisk,
    required this.events,
    required this.survivalProbability,
    required this.conversionProbability,
  });
}

class LeadConversionData {
  final String contactId;
  final String contactName;
  final String phoneNumber;
  final DateTime firstContactDate;
  final DateTime? conversionDate; // null if not converted yet (censored)
  final int daysToConversion; // -1 if not converted yet
  final bool isConverted;

  LeadConversionData({
    required this.contactId,
    required this.contactName,
    required this.phoneNumber,
    required this.firstContactDate,
    this.conversionDate,
    required this.daysToConversion,
    required this.isConverted,
  });
}

class KaplanMeierResult {
  final List<SurvivalDataPoint> survivalCurve;
  final int totalLeads;
  final int convertedLeads;
  final int censoredLeads; // Not yet converted
  final double? medianTimeToConversion; // Time when 50% have converted (null if <50% converted)
  final Map<int, double> conversionProbabilityAtTime; // Probability at key time points (1, 3, 7, 14, 30 days)

  KaplanMeierResult({
    required this.survivalCurve,
    required this.totalLeads,
    required this.convertedLeads,
    required this.censoredLeads,
    this.medianTimeToConversion,
    required this.conversionProbabilityAtTime,
  });
}

class KaplanMeierEstimator {
  /// Performs Kaplan-Meier survival analysis for lead conversion times
  /// Returns survival curve and key statistics
  Future<KaplanMeierResult> analyze(String userId) async {
    try {
      // Step 1: Collect conversion data for all contacts
      final leadData = await _collectLeadConversionData(userId);

      if (leadData.isEmpty) {
        return KaplanMeierResult(
          survivalCurve: [],
          totalLeads: 0,
          convertedLeads: 0,
          censoredLeads: 0,
          conversionProbabilityAtTime: {},
        );
      }

      // Step 2: Calculate Kaplan-Meier estimates
      final survivalCurve = _calculateKaplanMeier(leadData);

      // Step 3: Calculate summary statistics
      final totalLeads = leadData.length;
      final convertedLeads = leadData.where((l) => l.isConverted).length;
      final censoredLeads = totalLeads - convertedLeads;

      // Step 4: Find median time to conversion (time when S(t) = 0.5)
      final medianTime = _findMedianTime(survivalCurve);

      // Step 5: Get conversion probabilities at key time points
      final probAtTime = _getConversionProbabilitiesAtKeyTimes(survivalCurve);

      return KaplanMeierResult(
        survivalCurve: survivalCurve,
        totalLeads: totalLeads,
        convertedLeads: convertedLeads,
        censoredLeads: censoredLeads,
        medianTimeToConversion: medianTime,
        conversionProbabilityAtTime: probAtTime,
      );
    } catch (e) {
      print('Error in Kaplan-Meier analysis: $e');
      rethrow;
    }
  }

  /// Collects conversion data for all contacts
  /// Conversion = first successful/answered call
  Future<List<LeadConversionData>> _collectLeadConversionData(String userId) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    List<LeadConversionData> leadData = [];

    print('🔍 Kaplan-Meier: Starting data collection for userId: $userId');

    // Get all contacts
    QuerySnapshot contactsSnapshot = await firestore
        .collection('Contact Directories')
        .where('user_id', isEqualTo: userId)
        .get();

    print('📞 Found ${contactsSnapshot.docs.length} contacts in Contact Directories');

    // Fetch ALL call history for this user once (more efficient than per-contact queries)
    QuerySnapshot allCallsSnapshot = await firestore
        .collection('call_history')
        .where('user_id', isEqualTo: userId)
        .get();

    print('📱 Found ${allCallsSnapshot.docs.length} total calls in call_history');

    // Group calls by normalized phone number
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

    print('📊 Grouped calls into ${callsByPhone.length} unique phone numbers');

    for (var contactDoc in contactsSnapshot.docs) {
      final contactData = contactDoc.data() as Map<String, dynamic>;
      final contactName = contactData['contact_name'] ?? '';
      final phoneNumber = contactData['contact_phone_number'] ?? '';
      final normalizedPhone = contactData['normalized_phone'] ?? '';

      print('  👤 Processing contact: $contactName ($phoneNumber) - normalized: $normalizedPhone');

      if (normalizedPhone.isEmpty) {
        print('    ⚠️  Skipping - no normalized phone');
        continue;
      }

      // Get calls for this contact from our grouped map
      final contactCalls = callsByPhone[normalizedPhone] ?? [];

      print('    📱 Found ${contactCalls.length} calls for this contact');

      if (contactCalls.isEmpty) {
        print('    ⚠️  Skipping - no calls found');
        continue;
      }

      // Sort calls by timestamp
      contactCalls.sort((a, b) {
        final aTimestamp = a['timestamp'] as Timestamp?;
        final bTimestamp = b['timestamp'] as Timestamp?;
        if (aTimestamp == null || bTimestamp == null) return 0;
        return aTimestamp.compareTo(bTimestamp);
      });

      // Find first call (first contact date)
      final firstCall = contactCalls.first;
      final firstContactTimestamp = firstCall['timestamp'] as Timestamp?;
      if (firstContactTimestamp == null) {
        print('    ⚠️  Skipping - first call has no timestamp');
        continue;
      }
      final firstContactDate = firstContactTimestamp.toDate();

      print('    📅 First contact: ${firstContactDate.toString()}');

      // Find first successful call (conversion event)
      DateTime? conversionDate;
      for (var callData in contactCalls) {
        if (_wasCallAnswered(callData)) {
          final callTimestamp = callData['timestamp'] as Timestamp?;
          if (callTimestamp != null) {
            conversionDate = callTimestamp.toDate();
            print('    ✅ Conversion found: ${conversionDate.toString()}');
            break; // First successful call found
          }
        }
      }

      if (conversionDate == null) {
        print('    ⏳ No conversion yet (censored data)');
      }

      // Calculate days to conversion
      int daysToConversion;
      bool isConverted;

      if (conversionDate != null) {
        daysToConversion = conversionDate.difference(firstContactDate).inDays;
        isConverted = true;
      } else {
        // Not converted yet - censored data
        // Use current time to calculate follow-up time
        daysToConversion = DateTime.now().difference(firstContactDate).inDays;
        isConverted = false;
      }

      print('    📊 Days to conversion: $daysToConversion (converted: $isConverted)');

      leadData.add(LeadConversionData(
        contactId: contactDoc.id,
        contactName: contactName.isNotEmpty ? contactName : phoneNumber,
        phoneNumber: phoneNumber,
        firstContactDate: firstContactDate,
        conversionDate: conversionDate,
        daysToConversion: daysToConversion,
        isConverted: isConverted,
      ));
    }

    print('✅ Kaplan-Meier: Collected ${leadData.length} leads for analysis');
    return leadData;
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

  /// Calculates the Kaplan-Meier survival curve
  /// Formula: S(t) = Π(1 - dᵢ/nᵢ) for all i where tᵢ ≤ t
  List<SurvivalDataPoint> _calculateKaplanMeier(List<LeadConversionData> leadData) {
    // Group by time point (days to conversion)
    Map<int, int> eventsAtTime = {}; // Count of conversions at each day

    // Collect events
    for (var lead in leadData) {
      if (lead.isConverted) {
        final day = lead.daysToConversion;
        eventsAtTime[day] = (eventsAtTime[day] ?? 0) + 1;
      }
    }

    // Get all unique time points where events occurred, sorted
    List<int> timePoints = eventsAtTime.keys.toList()..sort();

    // Calculate survival probability at each time point
    List<SurvivalDataPoint> survivalCurve = [];
    double cumulativeSurvival = 1.0; // S(0) = 1.0 (everyone starts unconverted)

    for (var timePoint in timePoints) {
      // Count how many leads are "at risk" at this time point
      // At risk = haven't converted yet and have been followed long enough
      int atRisk = 0;
      for (var lead in leadData) {
        if (lead.isConverted) {
          // If converted, only at risk if conversion happened at or after this time
          if (lead.daysToConversion >= timePoint) {
            atRisk++;
          }
        } else {
          // If not converted (censored), at risk if follow-up time >= this time
          if (lead.daysToConversion >= timePoint) {
            atRisk++;
          }
        }
      }

      if (atRisk == 0) continue; // Skip if no one at risk

      final events = eventsAtTime[timePoint] ?? 0;

      // Apply Kaplan-Meier formula: S(t) = S(t-1) × (1 - dᵢ/nᵢ)
      final survivalAtThisTime = 1.0 - (events / atRisk);
      cumulativeSurvival *= survivalAtThisTime;

      survivalCurve.add(SurvivalDataPoint(
        timeInDays: timePoint,
        atRisk: atRisk,
        events: events,
        survivalProbability: cumulativeSurvival,
        conversionProbability: 1.0 - cumulativeSurvival,
      ));
    }

    return survivalCurve;
  }

  /// Finds the median time to conversion (time when 50% have converted)
  /// This is when S(t) crosses 0.5 (or conversion probability crosses 0.5)
  double? _findMedianTime(List<SurvivalDataPoint> survivalCurve) {
    if (survivalCurve.isEmpty) return null;

    // Find first time when survival probability <= 0.5 (conversion >= 0.5)
    for (var point in survivalCurve) {
      if (point.survivalProbability <= 0.5) {
        return point.timeInDays.toDouble();
      }
    }

    // If never reaches 50% conversion, return null
    return null;
  }

  /// Gets conversion probabilities at key time points (1, 3, 7, 14, 30 days)
  Map<int, double> _getConversionProbabilitiesAtKeyTimes(List<SurvivalDataPoint> survivalCurve) {
    final keyTimes = [1, 3, 7, 14, 30];
    Map<int, double> probabilities = {};

    for (var keyTime in keyTimes) {
      // Find the latest data point at or before this key time
      double conversionProb = 0.0;
      for (var point in survivalCurve) {
        if (point.timeInDays <= keyTime) {
          conversionProb = point.conversionProbability;
        } else {
          break;
        }
      }
      probabilities[keyTime] = conversionProb;
    }

    return probabilities;
  }

  /// Determines if a call was answered (successful conversion event)
  /// Uses same logic as other ML algorithms for consistency
  bool _wasCallAnswered(Map<String, dynamic> callData) {
    final answered = callData['answered'];
    bool isAnswered = false;

    if (answered is bool) {
      isAnswered = answered;
    } else if (answered is int) {
      isAnswered = answered == 1;
    }

    final callType = callData['call_type'] as String?;
    if (callType == 'Missed') {
      return false;
    }

    return isAnswered;
  }

  /// Gets interpretation message for conversion probability
  static String getConversionProbabilityInterpretation(double probability) {
    final percent = (probability * 100).toInt();
    if (percent >= 75) {
      return 'Very High - Most leads convert by this time';
    } else if (percent >= 50) {
      return 'High - Majority convert by this time';
    } else if (percent >= 25) {
      return 'Moderate - About half convert by this time';
    } else if (percent >= 10) {
      return 'Low - Only some convert by this time';
    } else {
      return 'Very Low - Few conversions by this time';
    }
  }
}
