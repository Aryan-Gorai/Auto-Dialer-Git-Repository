import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

/// MACHINE LEARNING ALGORITHM: Linear Regression (Least Squares Method)
/// 
/// FORMULA: y = β₀ + β₁x₁ + β₂x₂ + ... + βₙxₙ
/// 
/// PURPOSE: Predicts the likelihood of a lead (contact) converting based on:
///   - x₁: Number of calls made to the contact
///   - x₂: Total call duration (in minutes)
///   - x₃: Days since first contact
/// 
/// COEFFICIENTS CALCULATION: Using Least Squares Method
///   β = (XᵀX)⁻¹Xᵀy
///   where X is the feature matrix and y is the target vector (conversion rate)
/// 
/// CONVERSION DEFINITION: Percentage of answered calls out of total calls
///   Higher conversion = More engaged lead

class LeadData {
  final String contactId;
  final String contactName;
  final String phoneNumber;
  final int totalCalls;
  final double totalDurationMinutes;
  final int daysSinceFirstContact;
  final double conversionRate; // Actual conversion (answered calls / total calls)
  final double predictedConversion; // Predicted from linear regression

  LeadData({
    required this.contactId,
    required this.contactName,
    required this.phoneNumber,
    required this.totalCalls,
    required this.totalDurationMinutes,
    required this.daysSinceFirstContact,
    required this.conversionRate,
    this.predictedConversion = 0.0,
  });

  LeadData copyWith({double? predictedConversion}) {
    return LeadData(
      contactId: contactId,
      contactName: contactName,
      phoneNumber: phoneNumber,
      totalCalls: totalCalls,
      totalDurationMinutes: totalDurationMinutes,
      daysSinceFirstContact: daysSinceFirstContact,
      conversionRate: conversionRate,
      predictedConversion: predictedConversion ?? this.predictedConversion,
    );
  }
}

class LinearRegressionModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Regression coefficients calculated using Least Squares Method
  // β = [β₀, β₁, β₂, β₃] for [intercept, calls, duration, days]
  List<double>? _coefficients;
  
  String _normalizePhone(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length >= 9) {
      return digitsOnly.substring(digitsOnly.length - 9);
    }
    return digitsOnly;
  }

  /// Fetch all leads (contacts) with aggregated call statistics
  Future<List<LeadData>> fetchLeadsData(String userId) async {
    try {
      // Step 1: Fetch all contacts from Contact Directories
      final contactsSnapshot = await _firestore
          .collection('Contact Directories')
          .where('user_id', isEqualTo: userId)
          .get();

      // Step 2: Fetch all call history for this user
      final callHistorySnapshot = await _firestore
          .collection('call_history')
          .where('user_id', isEqualTo: userId)
          .get();

      // Step 3: Aggregate call data by normalized phone number
      Map<String, Map<String, dynamic>> callStatsByPhone = {};

      for (var callDoc in callHistorySnapshot.docs) {
        final data = callDoc.data();
        final address = data['address'] as String? ?? '';
        final normalizedPhone = _normalizePhone(address);
        
        if (normalizedPhone.isEmpty) continue;

        if (!callStatsByPhone.containsKey(normalizedPhone)) {
          callStatsByPhone[normalizedPhone] = {
            'total_calls': 0,
            'answered_calls': 0,
            'total_duration': 0.0,
            'first_contact': null,
          };
        }

        final stats = callStatsByPhone[normalizedPhone]!;
        stats['total_calls'] = (stats['total_calls'] as int) + 1;

        // Determine if call was answered (using same logic as Call History page)
        bool answered;
        if (data['answered'] is bool) {
          answered = data['answered'] as bool;
        } else if (data['answered'] is int) {
          answered = (data['answered'] as int) == 1;
        } else {
          answered = false;
        }

        final callType = (data['call_type'] as String? ?? '').trim();
        if (callType != 'Missed' && answered) {
          stats['answered_calls'] = (stats['answered_calls'] as int) + 1;
        }

        // Aggregate duration (convert seconds to minutes)
        final duration = (data['duration'] as num?)?.toDouble() ?? 0.0;
        stats['total_duration'] = (stats['total_duration'] as double) + (duration / 60.0);

        // Track first contact date
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        if (timestamp != null) {
          if (stats['first_contact'] == null || timestamp.isBefore(stats['first_contact'] as DateTime)) {
            stats['first_contact'] = timestamp;
          }
        }
      }

      // Step 4: Create LeadData objects for contacts with call history
      List<LeadData> leads = [];
      final now = DateTime.now();

      for (var contactDoc in contactsSnapshot.docs) {
        final contactData = contactDoc.data();
        final phoneNumber = contactData['contact_phone_number'] as String? ?? '';
        final normalizedPhone = _normalizePhone(phoneNumber);

        if (normalizedPhone.isEmpty || !callStatsByPhone.containsKey(normalizedPhone)) {
          continue; // Skip contacts with no call history
        }

        final stats = callStatsByPhone[normalizedPhone]!;
        final totalCalls = stats['total_calls'] as int;
        final answeredCalls = stats['answered_calls'] as int;
        final totalDuration = stats['total_duration'] as double;
        final firstContact = stats['first_contact'] as DateTime?;

        if (totalCalls == 0 || firstContact == null) continue;

        final daysSinceFirst = now.difference(firstContact).inDays;
        final conversionRate = answeredCalls / totalCalls;

        leads.add(LeadData(
          contactId: contactDoc.id,
          contactName: contactData['contact_name'] as String? ?? 'Unknown',
          phoneNumber: phoneNumber,
          totalCalls: totalCalls,
          totalDurationMinutes: totalDuration,
          daysSinceFirstContact: daysSinceFirst,
          conversionRate: conversionRate,
        ));
      }

      return leads;
    } catch (e) {
      print('Error fetching leads data: $e');
      return [];
    }
  }

  /// LEAST SQUARES METHOD IMPLEMENTATION
  /// 
  /// Calculate regression coefficients β using the formula:
  /// β = (XᵀX)⁻¹Xᵀy
  /// 
  /// Where:
  /// - X is the feature matrix [1, calls, duration, days] for each lead
  /// - y is the target vector (conversion rates)
  /// - Xᵀ is the transpose of X
  /// - (XᵀX)⁻¹ is the inverse of XᵀX
  void trainModel(List<LeadData> leads) {
    if (leads.length < 4) {
      print('⚠️ Not enough data to train model (need at least 4 leads)');
      _coefficients = [0.5, 0.0, 0.0, 0.0]; // Default coefficients
      return;
    }

    // Normalize features to prevent numerical instability
    final maxCalls = leads.map((l) => l.totalCalls).reduce(math.max).toDouble();
    final maxDuration = leads.map((l) => l.totalDurationMinutes).reduce(math.max);
    final maxDays = leads.map((l) => l.daysSinceFirstContact).reduce(math.max).toDouble();

    // Step 1: Build feature matrix X (n × 4) where n = number of leads
    // Each row: [1, normalized_calls, normalized_duration, normalized_days]
    List<List<double>> X = [];
    List<double> y = [];

    for (var lead in leads) {
      X.add([
        1.0, // Intercept term (β₀)
        maxCalls > 0 ? lead.totalCalls / maxCalls : 0.0, // Normalized calls (β₁)
        maxDuration > 0 ? lead.totalDurationMinutes / maxDuration : 0.0, // Normalized duration (β₂)
        maxDays > 0 ? lead.daysSinceFirstContact / maxDays : 0.0, // Normalized days (β₃)
      ]);
      y.add(lead.conversionRate);
    }

    // Step 2: Calculate Xᵀ (transpose of X)
    List<List<double>> XT = _transpose(X);

    // Step 3: Calculate XᵀX (4 × 4 matrix)
    List<List<double>> XTX = _matrixMultiply(XT, X);

    // Step 4: Calculate (XᵀX)⁻¹ (inverse of XᵀX)
    List<List<double>>? XTX_inv = _matrixInverse(XTX);
    
    if (XTX_inv == null) {
      print('⚠️ Matrix is singular, using default coefficients');
      _coefficients = [0.5, 0.0, 0.0, 0.0];
      return;
    }

    // Step 5: Calculate Xᵀy (4 × 1 vector)
    List<double> XTy = _matrixVectorMultiply(XT, y);

    // Step 6: Calculate β = (XᵀX)⁻¹Xᵀy
    _coefficients = _matrixVectorMultiply(XTX_inv, XTy);

    print('✅ Linear Regression Model Trained');
    print('📊 Coefficients: β₀=${_coefficients![0].toStringAsFixed(4)}, '
          'β₁=${_coefficients![1].toStringAsFixed(4)}, '
          'β₂=${_coefficients![2].toStringAsFixed(4)}, '
          'β₃=${_coefficients![3].toStringAsFixed(4)}');
  }

  /// Predict conversion likelihood for a lead using trained model
  /// Formula: y = β₀ + β₁x₁ + β₂x₂ + β₃x₃
  double predict(LeadData lead, {required double maxCalls, required double maxDuration, required double maxDays}) {
    if (_coefficients == null) {
      return 0.5; // Default prediction
    }

    // Normalize features
    final normalizedCalls = maxCalls > 0 ? lead.totalCalls / maxCalls : 0.0;
    final normalizedDuration = maxDuration > 0 ? lead.totalDurationMinutes / maxDuration : 0.0;
    final normalizedDays = maxDays > 0 ? lead.daysSinceFirstContact / maxDays : 0.0;

    // Apply linear regression formula
    final prediction = _coefficients![0] + // β₀ (intercept)
                      _coefficients![1] * normalizedCalls + // β₁ * x₁
                      _coefficients![2] * normalizedDuration + // β₂ * x₂
                      _coefficients![3] * normalizedDays; // β₃ * x₃

    // Clamp prediction between 0 and 1 (probability)
    return prediction.clamp(0.0, 1.0);
  }

  /// MATRIX OPERATIONS FOR LEAST SQUARES CALCULATION

  /// Transpose a matrix (swap rows and columns)
  List<List<double>> _transpose(List<List<double>> matrix) {
    if (matrix.isEmpty) return [];
    final rows = matrix.length;
    final cols = matrix[0].length;
    
    List<List<double>> result = List.generate(cols, (i) => List.filled(rows, 0.0));
    
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        result[j][i] = matrix[i][j];
      }
    }
    
    return result;
  }

  /// Multiply two matrices: A (m × n) × B (n × p) = C (m × p)
  List<List<double>> _matrixMultiply(List<List<double>> A, List<List<double>> B) {
    final m = A.length;
    final n = A[0].length;
    final p = B[0].length;
    
    List<List<double>> result = List.generate(m, (i) => List.filled(p, 0.0));
    
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < p; j++) {
        double sum = 0.0;
        for (int k = 0; k < n; k++) {
          sum += A[i][k] * B[k][j];
        }
        result[i][j] = sum;
      }
    }
    
    return result;
  }

  /// Multiply matrix A (m × n) by vector v (n × 1) = result (m × 1)
  List<double> _matrixVectorMultiply(List<List<double>> A, List<double> v) {
    final m = A.length;
    final n = A[0].length;
    
    List<double> result = List.filled(m, 0.0);
    
    for (int i = 0; i < m; i++) {
      double sum = 0.0;
      for (int j = 0; j < n; j++) {
        sum += A[i][j] * v[j];
      }
      result[i] = sum;
    }
    
    return result;
  }

  /// Calculate inverse of a matrix using Gaussian elimination
  /// Returns null if matrix is singular (non-invertible)
  List<List<double>>? _matrixInverse(List<List<double>> matrix) {
    final n = matrix.length;
    
    // Create augmented matrix [A | I]
    List<List<double>> augmented = List.generate(
      n,
      (i) => List.generate(2 * n, (j) => j < n ? matrix[i][j] : (i == j - n ? 1.0 : 0.0)),
    );
    
    // Forward elimination
    for (int i = 0; i < n; i++) {
      // Find pivot
      int maxRow = i;
      for (int k = i + 1; k < n; k++) {
        if (augmented[k][i].abs() > augmented[maxRow][i].abs()) {
          maxRow = k;
        }
      }
      
      // Swap rows
      if (maxRow != i) {
        final temp = augmented[i];
        augmented[i] = augmented[maxRow];
        augmented[maxRow] = temp;
      }
      
      // Check for singular matrix
      if (augmented[i][i].abs() < 1e-10) {
        return null;
      }
      
      // Scale pivot row
      final pivot = augmented[i][i];
      for (int j = 0; j < 2 * n; j++) {
        augmented[i][j] /= pivot;
      }
      
      // Eliminate column
      for (int k = 0; k < n; k++) {
        if (k != i) {
          final factor = augmented[k][i];
          for (int j = 0; j < 2 * n; j++) {
            augmented[k][j] -= factor * augmented[i][j];
          }
        }
      }
    }
    
    // Extract inverse from augmented matrix
    List<List<double>> inverse = List.generate(
      n,
      (i) => List.generate(n, (j) => augmented[i][j + n]),
    );
    
    return inverse;
  }

  /// Calculate R² (coefficient of determination) to measure model accuracy
  /// R² = 1 - (SS_res / SS_tot)
  /// where SS_res = Σ(y_actual - y_predicted)² and SS_tot = Σ(y_actual - y_mean)²
  double calculateR2(List<LeadData> leads) {
    if (leads.isEmpty || _coefficients == null) return 0.0;

    final maxCalls = leads.map((l) => l.totalCalls).reduce(math.max).toDouble();
    final maxDuration = leads.map((l) => l.totalDurationMinutes).reduce(math.max);
    final maxDays = leads.map((l) => l.daysSinceFirstContact).reduce(math.max).toDouble();

    double ssRes = 0.0; // Residual sum of squares
    double ssTot = 0.0; // Total sum of squares
    final yMean = leads.map((l) => l.conversionRate).reduce((a, b) => a + b) / leads.length;

    for (var lead in leads) {
      final yActual = lead.conversionRate;
      final yPredicted = predict(lead, maxCalls: maxCalls, maxDuration: maxDuration, maxDays: maxDays);
      
      ssRes += math.pow(yActual - yPredicted, 2);
      ssTot += math.pow(yActual - yMean, 2);
    }

    if (ssTot == 0) return 1.0;
    return 1 - (ssRes / ssTot);
  }
}
