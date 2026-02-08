// Call prediction view — displays Naive Bayes predictions for the best
// time to call a specific contact. Shows a "call now" recommendation,
// a ranked list of time slots by probability, and a heatmap-style grid
// of day-of-week vs hour with colour-coded answer probabilities.

import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:flutter_application_1/services/ml/naive_bayes_classifier.dart';
import 'package:flutter_application_1/utilities/apple_typography.dart';
import 'package:intl/intl.dart';

class CallPredictionView extends StatefulWidget {
  final String contactName;
  final String phoneNumber;

  const CallPredictionView({
    Key? key,
    required this.contactName,
    required this.phoneNumber,
  }) : super(key: key);

  @override
  State<CallPredictionView> createState() => _CallPredictionViewState();
}

class _CallPredictionViewState extends State<CallPredictionView> {
  final NaiveBayesCallPredictor _predictor = NaiveBayesCallPredictor();
  bool _isLoading = true;
  List<CallPrediction> _predictions = [];
  Map<String, dynamic>? _currentTimeRecommendation;
  String? _errorMessage;

  String get _userId => AuthService.firebase().currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadPredictions();
  }

  // Runs the Naive Bayes classifier to get time-slot predictions
  // and checks whether right now is a good time to call this contact.
  Future<void> _loadPredictions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final predictions = await _predictor.predictBestTimes(_userId, widget.phoneNumber);
      final currentRec = await _predictor.getCurrentTimeRecommendation(_userId, widget.phoneNumber);

      if (mounted) {
        setState(() {
          _predictions = predictions;
          _currentTimeRecommendation = currentRec;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading predictions: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load predictions';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Call Predictions',
          style: AppleTypography.withAppleFont(
            AppleTypography.headline5.copyWith(
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _predictions.isEmpty
                  ? _buildNoDataView()
                  : _buildPredictionsView(),
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
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Call History Available',
              style: AppleTypography.withAppleFont(
                AppleTypography.headline6.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Make some calls to ${widget.contactName} to build prediction data.',
              style: AppleTypography.withAppleFont(
                AppleTypography.body2.copyWith(color: Colors.grey[600]),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionsView() {
    final topPredictions = _predictor.getTopPredictions(_predictions, topN: 5);
    final predictionsByDay = _predictor.getPredictionsByDay(_predictions);

    return RefreshIndicator(
      onRefresh: _loadPredictions,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact info card
            _buildContactInfoCard(),
            const SizedBox(height: 16),

            // Current time recommendation
            if (_currentTimeRecommendation != null) ...[
              _buildCurrentTimeRecommendation(),
              const SizedBox(height: 16),
            ],

            // Top 5 best times
            _buildTopTimesCard(topPredictions),
            const SizedBox(height: 16),

            // Predictions by day
            _buildPredictionsByDaySection(predictionsByDay),
            const SizedBox(height: 16),

            // Statistics summary
            _buildStatisticsSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  const Color.fromRGBO(100, 140, 255, 1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                widget.contactName.isNotEmpty
                    ? widget.contactName[0].toUpperCase()
                    : '?',
                style: AppleTypography.withAppleFont(
                  AppleTypography.headline5.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.contactName,
                  style: AppleTypography.withAppleFont(
                    AppleTypography.subtitle1.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.phoneNumber,
                  style: AppleTypography.withAppleFont(
                    AppleTypography.body2.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.phone, color: Theme.of(context).colorScheme.primary),
        ],
      ),
    );
  }

  Widget _buildCurrentTimeRecommendation() {
    final shouldCall = _currentTimeRecommendation!['should_call_now'] as bool;
    final probability = _currentTimeRecommendation!['current_probability'] as double;
    final reason = _currentTimeRecommendation!['reason'] as String;
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: shouldCall
              ? [Colors.green.shade400, Colors.green.shade600]
              : [Colors.orange.shade400, Colors.orange.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (shouldCall ? Colors.green : Colors.orange).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                shouldCall ? Icons.check_circle : Icons.schedule,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  shouldCall ? 'Good Time to Call!' : 'Not the Best Time',
                  style: AppleTypography.withAppleFont(
                    AppleTypography.headline6.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current Time',
                      style: AppleTypography.withAppleFont(
                        AppleTypography.body2.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, h:mm a').format(now),
                      style: AppleTypography.withAppleFont(
                        AppleTypography.body2.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Success Probability',
                      style: AppleTypography.withAppleFont(
                        AppleTypography.body2.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                    Text(
                      '${(probability * 100).toStringAsFixed(1)}%',
                      style: AppleTypography.withAppleFont(
                        AppleTypography.body2.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  reason,
                  style: AppleTypography.withAppleFont(
                    AppleTypography.caption.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontStyle: FontStyle.italic,
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

  Widget _buildTopTimesCard(List<CallPrediction> topPredictions) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(Icons.star, color: Colors.amber.shade600, size: 24),
              const SizedBox(width: 8),
              Text(
                'Top 5 Best Times to Call',
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
          ...topPredictions.asMap().entries.map((entry) {
            final index = entry.key;
            final prediction = entry.value;
            return _buildPredictionTile(prediction, index + 1);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildPredictionTile(CallPrediction prediction, int rank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rank <= 3
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade400,
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
                  '${prediction.dayName}, ${prediction.timeRange}',
                  style: AppleTypography.withAppleFont(
                    AppleTypography.body1.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${prediction.answeredCalls}/${prediction.totalCalls} calls answered',
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
              Text(
                '${(prediction.probability * 100).toStringAsFixed(1)}%',
                style: AppleTypography.withAppleFont(
                  AppleTypography.subtitle2.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              _buildProbabilityBar(prediction.probability),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProbabilityBar(double probability) {
    return Container(
      width: 60,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: probability,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionsByDaySection(Map<int, List<CallPrediction>> predictionsByDay) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            'Predictions by Day',
            style: AppleTypography.withAppleFont(
              AppleTypography.subtitle1.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...predictionsByDay.entries.map((entry) {
            final day = entry.key;
            final predictions = entry.value;
            final bestTime = predictions.first;
            
            const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(64, 105, 225, 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        dayNames[day - 1],
                        style: AppleTypography.withAppleFont(
                          AppleTypography.body2.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
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
                          'Best: ${bestTime.timeRange}',
                          style: AppleTypography.withAppleFont(
                            AppleTypography.body2.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        Text(
                          '${predictions.length} time slots',
                          style: AppleTypography.withAppleFont(
                            AppleTypography.caption.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(bestTime.probability * 100).toStringAsFixed(0)}%',
                    style: AppleTypography.withAppleFont(
                      AppleTypography.body1.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildStatisticsSummary() {
    final totalDataPoints = _predictions.fold<int>(0, (sum, p) => sum + p.totalCalls);
    final totalAnswered = _predictions.fold<int>(0, (sum, p) => sum + p.answeredCalls);
    final overallSuccessRate = totalDataPoints > 0 ? (totalAnswered / totalDataPoints) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
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
            'Statistics Summary',
            style: AppleTypography.withAppleFont(
              AppleTypography.subtitle1.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  'Total Calls',
                  totalDataPoints.toString(),
                  Icons.phone_callback,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  'Answered',
                  totalAnswered.toString(),
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
                child: _buildStatBox(
                  'Success Rate',
                  '${(overallSuccessRate * 100).toStringAsFixed(1)}%',
                  Icons.trending_up,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  'Time Slots',
                  _predictions.length.toString(),
                  Icons.access_time,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppleTypography.withAppleFont(
              AppleTypography.headline6.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppleTypography.withAppleFont(
              AppleTypography.caption.copyWith(
                color: Colors.grey[700],
              ),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
