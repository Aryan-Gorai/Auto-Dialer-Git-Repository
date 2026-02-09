// Call prediction view — displays Naive Bayes predictions for the best
// time to call a specific contact. Shows a "call now" recommendation,
// a ranked list of time slots by probability, and a heatmap-style grid
// of day-of-week vs hour with colour-coded answer probabilities.

import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:flutter_application_1/services/ml/naive_bayes_classifier.dart';
import 'package:flutter_application_1/theme/components/app_components.dart';
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
        title: const Text(
          'Call Predictions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.normal,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppDesignTokens.primary,
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
            Icon(Icons.error_outline, size: 64, color: AppDesignTokens.dangerLight),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Unknown error',
              style: const TextStyle(
                fontSize: 16,
                color: AppDesignTokens.neutral700,
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
            Icon(Icons.analytics_outlined, size: 64, color: AppDesignTokens.neutral400),
            const SizedBox(height: 16),
            Text(
              'No Call History Available',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppDesignTokens.neutral800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Make some calls to ${widget.contactName} to build prediction data.',
              style: const TextStyle(
                fontSize: 14,
                color: AppDesignTokens.neutral600,
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
        color: AppDesignTokens.surface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
        boxShadow: AppDesignTokens.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: AppDesignTokens.primaryGradient,
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
            ),
            child: Center(
              child: Text(
                widget.contactName.isNotEmpty
                    ? widget.contactName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppDesignTokens.neutral800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.phoneNumber,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppDesignTokens.neutral600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.phone, color: AppDesignTokens.primary),
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
              ? [AppDesignTokens.success, AppDesignTokens.successDark]
              : [AppDesignTokens.warning, AppDesignTokens.warningDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
        boxShadow: shouldCall
            ? [BoxShadow(color: AppDesignTokens.success.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
            : [BoxShadow(color: AppDesignTokens.warning.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current Time',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, h:mm a').format(now),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    Text(
                      '${(probability * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  reason,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                    fontStyle: FontStyle.italic,
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
        color: AppDesignTokens.surface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
        boxShadow: AppDesignTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: AppDesignTokens.warning, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Top 5 Best Times to Call',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppDesignTokens.neutral800,
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
        color: AppDesignTokens.neutral50,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
        border: Border.all(color: AppDesignTokens.neutral200),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rank <= 3
                  ? AppDesignTokens.primary
                  : AppDesignTokens.neutral400,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.neutral800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${prediction.answeredCalls}/${prediction.totalCalls} calls answered',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppDesignTokens.neutral600,
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppDesignTokens.primary,
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
        color: AppDesignTokens.neutral200,
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: probability,
        child: Container(
          decoration: BoxDecoration(
            color: AppDesignTokens.primary,
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
        color: AppDesignTokens.surface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
        boxShadow: AppDesignTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Predictions by Day',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppDesignTokens.neutral800,
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
                color: AppDesignTokens.neutral50,
                borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.primarySoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        dayNames[day - 1],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppDesignTokens.primary,
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
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppDesignTokens.neutral800,
                          ),
                        ),
                        Text(
                          '${predictions.length} time slots',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppDesignTokens.neutral600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(bestTime.probability * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppDesignTokens.primary,
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
        color: AppDesignTokens.surface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
        boxShadow: AppDesignTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistics Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppDesignTokens.neutral800,
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
                  AppDesignTokens.accentBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  'Answered',
                  totalAnswered.toString(),
                  Icons.check_circle,
                  AppDesignTokens.success,
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
                  AppDesignTokens.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  'Time Slots',
                  _predictions.length.toString(),
                  Icons.access_time,
                  AppDesignTokens.warning,
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
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppDesignTokens.neutral700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
