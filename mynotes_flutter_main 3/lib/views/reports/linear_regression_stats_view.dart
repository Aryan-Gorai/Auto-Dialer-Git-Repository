// ML statistics view combining three statistical models:
//   1. Linear Regression — predicts future call success from historical trends
//   2. Wilson Score — ranks contacts by answer reliability with confidence intervals
//   3. Kaplan-Meier — survival analysis estimating how long until a contact answers
// Each section fetches data from call_history and renders charts + tables.

import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:flutter_application_1/services/ml/linear_regression.dart';
import 'package:flutter_application_1/services/ml/wilson_score.dart';
import 'package:flutter_application_1/services/ml/kaplan_meier.dart';
import 'package:flutter_application_1/utilities/apple_typography.dart';

class LinearRegressionStatsView extends StatefulWidget {
  final String? targetUserId;
  const LinearRegressionStatsView({Key? key, this.targetUserId}) : super(key: key);

  @override
  State<LinearRegressionStatsView> createState() => _LinearRegressionStatsViewState();
}

class _LinearRegressionStatsViewState extends State<LinearRegressionStatsView> {
  final LinearRegressionModel _model = LinearRegressionModel();
  final WilsonScoreCalculator _wilsonCalculator = WilsonScoreCalculator();
  final KaplanMeierEstimator _kaplanMeier = KaplanMeierEstimator();
  
  bool _isLoading = true;
  List<LeadData> _leads = [];
  double _r2Score = 0.0;
  String? _errorMessage;
  
  // Wilson Score data
  List<WilsonScoreResult> _wilsonResults = [];
  
  // Kaplan-Meier data
  KaplanMeierResult? _kaplanMeierResult;
  
  // Expansion states for collapsible sections
  bool _isLinearRegressionExpanded = true;
  bool _isWilsonScoreExpanded = true;
  bool _isKaplanMeierExpanded = true;

  String get _userId => widget.targetUserId ?? AuthService.firebase().currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadAndTrainModel();
  }

  // Fetches all lead data from Firestore, trains the linear regression
  // model using the Least Squares method, then runs predictions.
  // Also loads Kaplan-Meier survival data and Wilson Score rankings.
  Future<void> _loadAndTrainModel() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch lead data from Firebase for Linear Regression
      final leads = await _model.fetchLeadsData(_userId);

      if (leads.isEmpty) {
        setState(() {
          _errorMessage = 'No leads with call history found';
          _isLoading = false;
        });
        return;
      }

      // Train the linear regression model using Least Squares Method
      _model.trainModel(leads);

      // Calculate max values for normalization
      final maxCalls = leads.map((l) => l.totalCalls).reduce((a, b) => a > b ? a : b).toDouble();
      final maxDuration = leads.map((l) => l.totalDurationMinutes).reduce((a, b) => a > b ? a : b);
      final maxDays = leads.map((l) => l.daysSinceFirstContact).reduce((a, b) => a > b ? a : b).toDouble();

      // Make predictions for each lead
      final leadsWithPredictions = leads.map((lead) {
        final prediction = _model.predict(
          lead,
          maxCalls: maxCalls,
          maxDuration: maxDuration,
          maxDays: maxDays,
        );
        return lead.copyWith(predictedConversion: prediction);
      }).toList();

      // Sort by predicted conversion (highest first)
      leadsWithPredictions.sort((a, b) => b.predictedConversion.compareTo(a.predictedConversion));

      // Calculate R² score (model accuracy)
      final r2 = _model.calculateR2(leads);

      // Calculate Wilson Score intervals for all contacts
      final wilsonResults = await _wilsonCalculator.calculateForAllContacts(_userId);

      // Perform Kaplan-Meier survival analysis
      final kaplanMeierResult = await _kaplanMeier.analyze(_userId);

      if (mounted) {
        setState(() {
          _leads = leadsWithPredictions;
          _r2Score = r2;
          _wilsonResults = wilsonResults;
          _kaplanMeierResult = kaplanMeierResult;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error training model: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to train model: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page title
              Text(
                'Machine Learning Analytics',
                style: AppleTypography.withAppleFont(
                  AppleTypography.headline4.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Advanced statistical analysis powered by AI',
                style: AppleTypography.withAppleFont(
                  AppleTypography.body2.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_errorMessage != null)
                _buildErrorView()
              else
                Column(
                  children: [
                    // Linear Regression Section (Collapsible)
                    _buildLinearRegressionSection(),
                    const SizedBox(height: 16),

                    // Wilson Score Section (Collapsible)
                    _buildWilsonScoreSection(),
                    const SizedBox(height: 16),

                    // Kaplan-Meier Section (Collapsible)
                    _buildKaplanMeierSection(),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinearRegressionSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isLinearRegressionExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _isLinearRegressionExpanded = expanded;
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color.fromRGBO(64, 105, 225, 1),
                  Color.fromRGBO(100, 140, 255, 1),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.functions,
              color: Colors.white,
              size: 24,
            ),
          ),
          title: Text(
            'Linear Regression',
            style: AppleTypography.withAppleFont(
              AppleTypography.headline6.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          subtitle: Text(
            'Predict lead conversion likelihood',
            style: AppleTypography.withAppleFont(
              AppleTypography.caption.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          children: [
            // Algorithm explanation
            _buildAlgorithmHeader(),
            const SizedBox(height: 16),
            
            // Model accuracy card
            _buildModelAccuracyCard(),
            const SizedBox(height: 16),
            
            // Lead predictions list
            _buildLeadsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildWilsonScoreSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isWilsonScoreExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _isWilsonScoreExpanded = expanded;
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color.fromRGBO(138, 43, 226, 1),
                  Color.fromRGBO(168, 85, 247, 1),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.analytics,
              color: Colors.white,
              size: 24,
            ),
          ),
          title: Text(
            'Wilson Score',
            style: AppleTypography.withAppleFont(
              AppleTypography.headline6.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          subtitle: Text(
            'Statistical confidence in success rates',
            style: AppleTypography.withAppleFont(
              AppleTypography.caption.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          children: [
            // Algorithm explanation
            _buildWilsonScoreHeader(),
            const SizedBox(height: 16),
            
            // Wilson Score results
            _buildWilsonScoreList(),
          ],
        ),
      ),
    );
  }

  Widget _buildWilsonScoreHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color.fromRGBO(138, 43, 226, 1),
            Color.fromRGBO(168, 85, 247, 1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(138, 43, 226, 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How Wilson Score Works',
            style: AppleTypography.withAppleFont(
              AppleTypography.headline6.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Formula: CI = (p + z²/2n ± z√(p(1-p)/n + z²/4n²)) / (1 + z²/n)',
                  style: AppleTypography.withAppleFont(
                    AppleTypography.body2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'What it does:',
                  style: AppleTypography.withAppleFont(
                    AppleTypography.body2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildWilsonExplanationPoint(
                  'Calculates how confident we can be in each contact\'s success rate'
                ),
                _buildWilsonExplanationPoint(
                  'Accounts for sample size: more calls = more confidence'
                ),
                _buildWilsonExplanationPoint(
                  'Uses 95% confidence interval (z=1.96)'
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Example:',
                            style: AppleTypography.withAppleFont(
                              AppleTypography.body2.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '• Contact A: 10/10 calls successful (100%)',
                        style: AppleTypography.withAppleFont(
                          AppleTypography.caption.copyWith(
                            color: Colors.white.withOpacity(0.95),
                          ),
                        ),
                      ),
                      Text(
                        '  Wilson says: "Only 10 calls... true rate is 72%-100%"',
                        style: AppleTypography.withAppleFont(
                          AppleTypography.caption.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Contact B: 45/50 calls successful (90%)',
                        style: AppleTypography.withAppleFont(
                          AppleTypography.caption.copyWith(
                            color: Colors.white.withOpacity(0.95),
                          ),
                        ),
                      ),
                      Text(
                        '  Wilson says: "50 calls is solid... true rate is 82%-96%"',
                        style: AppleTypography.withAppleFont(
                          AppleTypography.caption.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '→ Contact B is more reliable despite lower percentage!',
                        style: AppleTypography.withAppleFont(
                          AppleTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWilsonExplanationPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppleTypography.withAppleFont(
                AppleTypography.caption.copyWith(
                  color: Colors.white.withOpacity(0.95),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWilsonScoreList() {
    if (_wilsonResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'No data available for Wilson Score analysis',
            style: AppleTypography.withAppleFont(
              AppleTypography.body2.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 24),
            const SizedBox(width: 8),
            Text(
              'Confidence Rankings',
              style: AppleTypography.withAppleFont(
                AppleTypography.subtitle1.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Contacts ranked by statistical confidence (most reliable first)',
          style: AppleTypography.withAppleFont(
            AppleTypography.caption.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ..._wilsonResults.asMap().entries.map((entry) {
          final index = entry.key;
          final result = entry.value;
          return _buildWilsonScoreTile(result, index + 1);
        }).toList(),
      ],
    );
  }

  Widget _buildWilsonScoreTile(WilsonScoreResult result, int rank) {
    final confidenceColor = _getConfidenceColor(result.confidenceScore);
    final interpretation = WilsonScoreCalculator.getConfidenceInterpretation(result.confidenceScore);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: confidenceColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: confidenceColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: AppleTypography.withAppleFont(
                      AppleTypography.body2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.contactName,
                      style: AppleTypography.withAppleFont(
                        AppleTypography.body1.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result.phoneNumber,
                      style: AppleTypography.withAppleFont(
                        AppleTypography.caption.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: confidenceColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, size: 14, color: confidenceColor),
                        const SizedBox(width: 4),
                        Text(
                          '${result.confidenceScore.toStringAsFixed(0)}%',
                          style: AppleTypography.withAppleFont(
                            AppleTypography.body2.copyWith(
                              fontWeight: FontWeight.bold,
                              color: confidenceColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'confidence',
                    style: AppleTypography.withAppleFont(
                      AppleTypography.caption.copyWith(
                        color: Colors.grey[500],
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Success rate with confidence interval
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Success Rate:',
                      style: AppleTypography.withAppleFont(
                        AppleTypography.caption.copyWith(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${(result.successRate * 100).toStringAsFixed(1)}%',
                      style: AppleTypography.withAppleFont(
                        AppleTypography.body1.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '95% Confidence Interval:',
                      style: AppleTypography.withAppleFont(
                        AppleTypography.caption.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    Text(
                      '${(result.lowerBound * 100).toStringAsFixed(1)}% - ${(result.upperBound * 100).toStringAsFixed(1)}%',
                      style: AppleTypography.withAppleFont(
                        AppleTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: confidenceColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Stack(
                    children: [
                      // Confidence interval bar
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: result.upperBound,
                        child: Container(
                          decoration: BoxDecoration(
                            color: confidenceColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      // Success rate marker
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: result.successRate,
                        child: Container(
                          decoration: BoxDecoration(
                            color: confidenceColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatChip(
                  Icons.phone,
                  '${result.successfulCalls}/${result.totalCalls} answered',
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: confidenceColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 14, color: confidenceColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          interpretation,
                          style: AppleTypography.withAppleFont(
                            AppleTypography.caption.copyWith(
                              color: confidenceColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Maps confidence scores to traffic-light colours:
  // green (>=75), orange (>=50), red (<50).
  Color _getConfidenceColor(double confidenceScore) {
    if (confidenceScore >= 75) {
      return Colors.green;
    } else if (confidenceScore >= 50) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Widget _buildKaplanMeierSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isKaplanMeierExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _isKaplanMeierExpanded = expanded;
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color.fromRGBO(34, 139, 34, 1),
                  Color.fromRGBO(60, 179, 113, 1),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.timeline,
              color: Colors.white,
              size: 24,
            ),
          ),
          title: Text(
            'Kaplan-Meier Estimator',
            style: AppleTypography.withAppleFont(
              AppleTypography.headline6.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          subtitle: Text(
            'Time-to-conversion survival analysis',
            style: AppleTypography.withAppleFont(
              AppleTypography.caption.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          children: [
            // Algorithm explanation
            _buildKaplanMeierHeader(),
            const SizedBox(height: 16),
            
            // Kaplan-Meier results
            _buildKaplanMeierResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildKaplanMeierHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color.fromRGBO(34, 139, 34, 1),
            Color.fromRGBO(60, 179, 113, 1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(34, 139, 34, 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How Kaplan-Meier Works',
            style: AppleTypography.withAppleFont(
              AppleTypography.headline6.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Formula: S(t) = Π(1 - dᵢ/nᵢ) for all i where tᵢ ≤ t',
                  style: AppleTypography.withAppleFont(
                    AppleTypography.body2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'What it does:',
                  style: AppleTypography.withAppleFont(
                    AppleTypography.body2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildKaplanMeierExplanationPoint(
                  'Predicts how long it takes for leads to convert (first successful call)'
                ),
                _buildKaplanMeierExplanationPoint(
                  'Handles "censored" data: leads that haven\'t converted yet'
                ),
                _buildKaplanMeierExplanationPoint(
                  'Shows probability of conversion at different time points'
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Example:',
                            style: AppleTypography.withAppleFont(
                              AppleTypography.body2.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '• Day 1: 100 leads, 10 convert → 90% haven\'t converted',
                        style: AppleTypography.withAppleFont(
                          AppleTypography.caption.copyWith(
                            color: Colors.white.withOpacity(0.95),
                          ),
                        ),
                      ),
                      Text(
                        '• Day 3: 85 leads left, 15 convert → 70% haven\'t converted',
                        style: AppleTypography.withAppleFont(
                          AppleTypography.caption.copyWith(
                            color: Colors.white.withOpacity(0.95),
                          ),
                        ),
                      ),
                      Text(
                        '• Day 7: 60 leads left, 20 convert → 47% haven\'t converted',
                        style: AppleTypography.withAppleFont(
                          AppleTypography.caption.copyWith(
                            color: Colors.white.withOpacity(0.95),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '→ By day 7, 53% of leads have converted!',
                        style: AppleTypography.withAppleFont(
                          AppleTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKaplanMeierExplanationPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppleTypography.withAppleFont(
                AppleTypography.caption.copyWith(
                  color: Colors.white.withOpacity(0.95),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKaplanMeierResults() {
    if (_kaplanMeierResult == null || _kaplanMeierResult!.totalLeads == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'No data available for Kaplan-Meier analysis',
            style: AppleTypography.withAppleFont(
              AppleTypography.body2.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
        ),
      );
    }

    final result = _kaplanMeierResult!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary statistics card
        _buildKaplanMeierSummaryCard(result),
        const SizedBox(height: 16),

        // Conversion probabilities at key time points
        _buildConversionTimelineCard(result),
        const SizedBox(height: 16),

        // Survival curve data points
        if (result.survivalCurve.isNotEmpty)
          _buildSurvivalCurveCard(result),
      ],
    );
  }

  Widget _buildKaplanMeierSummaryCard(KaplanMeierResult result) {
    final conversionRate = result.totalLeads > 0 
        ? (result.convertedLeads / result.totalLeads) 
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.summarize, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              Text(
                'Summary Statistics',
                style: AppleTypography.withAppleFont(
                  AppleTypography.subtitle1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryStatItem(
                  'Total Leads',
                  '${result.totalLeads}',
                  Icons.people,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryStatItem(
                  'Converted',
                  '${result.convertedLeads}',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryStatItem(
                  'Not Yet Converted',
                  '${result.censoredLeads}',
                  Icons.hourglass_empty,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryStatItem(
                  'Conversion Rate',
                  '${(conversionRate * 100).toStringAsFixed(1)}%',
                  Icons.trending_up,
                  Colors.purple,
                ),
              ),
            ],
          ),
          if (result.medianTimeToConversion != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color.fromRGBO(34, 139, 34, 0.1),
                    Color.fromRGBO(60, 179, 113, 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color.fromRGBO(34, 139, 34, 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    color: Color.fromRGBO(34, 139, 34, 1),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Median Time to Conversion',
                          style: AppleTypography.withAppleFont(
                            AppleTypography.caption.copyWith(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${result.medianTimeToConversion!.toInt()} days',
                          style: AppleTypography.withAppleFont(
                            AppleTypography.headline5.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color.fromRGBO(34, 139, 34, 1),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '50% of leads convert by this time',
                          style: AppleTypography.withAppleFont(
                            AppleTypography.caption.copyWith(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: AppleTypography.withAppleFont(
                    AppleTypography.caption.copyWith(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppleTypography.withAppleFont(
              AppleTypography.headline6.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversionTimelineCard(KaplanMeierResult result) {
    final keyTimes = [1, 3, 7, 14, 30];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              Text(
                'Conversion Timeline',
                style: AppleTypography.withAppleFont(
                  AppleTypography.subtitle1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Probability of conversion at key time points',
            style: AppleTypography.withAppleFont(
              AppleTypography.caption.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...keyTimes.map((days) {
            final probability = result.conversionProbabilityAtTime[days] ?? 0.0;
            final percent = (probability * 100);
            return _buildTimelineItem(days, percent);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(int days, double percent) {
    final color = _getTimelineColor(percent);
    String dayLabel;
    if (days == 1) {
      dayLabel = '1 day';
    } else {
      dayLabel = '$days days';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                dayLabel,
                style: AppleTypography.withAppleFont(
                  AppleTypography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 11,
                  ),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        'Conversion Probability',
                        style: AppleTypography.withAppleFont(
                          AppleTypography.caption.copyWith(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${percent.toStringAsFixed(1)}%',
                      style: AppleTypography.withAppleFont(
                        AppleTypography.body2.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: (percent / 100).clamp(0.0, 1.0),
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurvivalCurveCard(KaplanMeierResult result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              Text(
                'Survival Curve Data',
                style: AppleTypography.withAppleFont(
                  AppleTypography.subtitle1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Detailed conversion events over time',
            style: AppleTypography.withAppleFont(
              AppleTypography.caption.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Day',
                    style: AppleTypography.withAppleFont(
                      AppleTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'At Risk',
                    style: AppleTypography.withAppleFont(
                      AppleTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Converted',
                    style: AppleTypography.withAppleFont(
                      AppleTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Conversion %',
                    style: AppleTypography.withAppleFont(
                      AppleTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Show first 10 data points
          ...result.survivalCurve.take(10).map((point) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${point.timeInDays}',
                      style: AppleTypography.withAppleFont(
                        AppleTypography.body2.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${point.atRisk}',
                      style: AppleTypography.withAppleFont(
                        AppleTypography.body2.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${point.events}',
                      style: AppleTypography.withAppleFont(
                        AppleTypography.body2.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${(point.conversionProbability * 100).toStringAsFixed(1)}%',
                      style: AppleTypography.withAppleFont(
                        AppleTypography.body2.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _getTimelineColor(point.conversionProbability * 100),
                        ),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          if (result.survivalCurve.length > 10) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                '... and ${result.survivalCurve.length - 10} more data points',
                style: AppleTypography.withAppleFont(
                  AppleTypography.caption.copyWith(
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getTimelineColor(double percent) {
    if (percent >= 60) {
      return Colors.green;
    } else if (percent >= 30) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Widget _buildAlgorithmHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color.fromRGBO(64, 105, 225, 1),
            Color.fromRGBO(100, 140, 255, 1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(64, 105, 225, 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How Linear Regression Works',
            style: AppleTypography.withAppleFont(
              AppleTypography.headline6.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Formula: y = β₀ + β₁x₁ + β₂x₂ + β₃x₃',
                  style: AppleTypography.withAppleFont(
                    AppleTypography.body1.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Predicts lead conversion based on:',
                  style: AppleTypography.withAppleFont(
                    AppleTypography.caption.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                ...[
                  'x₁: Total number of calls',
                  'x₂: Total call duration (minutes)',
                  'x₃: Days since first contact',
                ].map((feature) => Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            feature,
                            style: AppleTypography.withAppleFont(
                              AppleTypography.caption.copyWith(
                                color: Colors.white.withOpacity(0.95),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 8),
                Text(
                  'Uses Least Squares Method: β = (XᵀX)⁻¹Xᵀy',
                  style: AppleTypography.withAppleFont(
                    AppleTypography.caption.copyWith(
                      color: Colors.white.withOpacity(0.85),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelAccuracyCard() {
    final percentage = (_r2Score * 100).clamp(0, 100);
    final isGoodFit = percentage >= 60;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isGoodFit ? Icons.trending_up : Icons.info_outline,
                color: isGoodFit ? Colors.green : Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Model Accuracy (R² Score)',
                style: AppleTypography.withAppleFont(
                  AppleTypography.subtitle1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: AppleTypography.withAppleFont(
                        AppleTypography.headline3.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isGoodFit ? Colors.green : Colors.orange.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isGoodFit
                          ? 'Good model fit - predictions are reliable'
                          : 'Moderate fit - more data may improve accuracy',
                      style: AppleTypography.withAppleFont(
                        AppleTypography.caption.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _r2Score.clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              isGoodFit ? Colors.green : Colors.orange.shade700,
            ),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Trained on ${_leads.length} leads with call history',
                    style: AppleTypography.withAppleFont(
                      AppleTypography.caption.copyWith(
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadsList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lead Conversion Predictions',
            style: AppleTypography.withAppleFont(
              AppleTypography.subtitle1.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ranked by predicted conversion likelihood (highest first)',
            style: AppleTypography.withAppleFont(
              AppleTypography.caption.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ..._leads.asMap().entries.map((entry) {
            final index = entry.key;
            final lead = entry.value;
            return _buildLeadTile(lead, index + 1);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildLeadTile(LeadData lead, int rank) {
    final predictionPct = (lead.predictedConversion * 100).clamp(0, 100);
    final actualPct = (lead.conversionRate * 100).clamp(0, 100);
    final isHighPotential = predictionPct >= 60;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighPotential
              ? Colors.green.withOpacity(0.3)
              : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isHighPotential ? Colors.green : Colors.grey.shade400,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: AppleTypography.withAppleFont(
                      AppleTypography.body2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.contactName,
                      style: AppleTypography.withAppleFont(
                        AppleTypography.body1.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lead.phoneNumber,
                      style: AppleTypography.withAppleFont(
                        AppleTypography.caption.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isHighPotential
                          ? Colors.green.withOpacity(0.2)
                          : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${predictionPct.toStringAsFixed(0)}%',
                      style: AppleTypography.withAppleFont(
                        AppleTypography.body2.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isHighPotential ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'predicted',
                    style: AppleTypography.withAppleFont(
                      AppleTypography.caption.copyWith(
                        color: Colors.grey[500],
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatChip(
                  Icons.phone,
                  '${lead.totalCalls} calls',
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatChip(
                  Icons.timer,
                  '${lead.totalDurationMinutes.toStringAsFixed(1)}m',
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatChip(
                  Icons.calendar_today,
                  '${lead.daysSinceFirstContact}d',
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Actual: ',
                style: AppleTypography.withAppleFont(
                  AppleTypography.caption.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Text(
                '${actualPct.toStringAsFixed(0)}%',
                style: AppleTypography.withAppleFont(
                  AppleTypography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (actualPct / 100).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade600,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: AppleTypography.withAppleFont(
                AppleTypography.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Unknown error',
              style: AppleTypography.withAppleFont(
                AppleTypography.body1.copyWith(color: Colors.grey[700]),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAndTrainModel,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(64, 105, 225, 1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
