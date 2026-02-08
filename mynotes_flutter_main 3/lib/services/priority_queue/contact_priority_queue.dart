import 'package:cloud_firestore/cloud_firestore.dart';

/// Contact with priority score for min-heap ordering
/// 
/// Wraps contact data with a calculated priority score
/// Lower score = higher priority (should be called sooner)
class PrioritizedContact {
  final Map<String, dynamic> contactData;
  final double priorityScore;
  
  PrioritizedContact({
    required this.contactData,
    required this.priorityScore,
  });
  
  String get contactName => contactData['contact_name'] ?? '';
  String get phoneNumber => contactData['contact_phone_number'] ?? '';
  int get originalIndex => contactData['contact_index'] ?? 0;
}

/// Min-Heap Priority Queue for efficient contact retrieval
/// 
/// Data Structure: Binary Min-Heap
/// - Always maintains the minimum priority (most urgent) contact at the root
/// - Implemented using an array-based binary tree
/// - Parent at index i, children at 2i+1 and 2i+2
/// 
/// Time Complexity:
/// - Insert: O(log n) - Add contact and bubble up
/// - Extract-Min: O(log n) - Remove root and bubble down
/// - Peek: O(1) - View most urgent contact
/// - Build Heap: O(n log n) - Insert all contacts
/// 
/// Space Complexity: O(n) where n = number of contacts
/// 
/// Use Case:
/// Automatically determine the optimal calling order based on:
/// 1. Time since last call (days)
/// 2. Call success rate (answered/total)
/// 3. Average call rating
/// 4. Total call attempts
/// 5. Days since last successful call
class ContactPriorityQueue {
  /// Internal heap storage (array-based binary tree)
  final List<PrioritizedContact> _heap = [];
  
  /// Get current size of the priority queue
  int get size => _heap.length;
  
  /// Check if queue is empty
  bool get isEmpty => _heap.isEmpty;
  
  /// Check if queue has contacts
  bool get isNotEmpty => _heap.isNotEmpty;
  
  /// Get parent index in binary tree
  /// Parent of node at index i is at (i-1)/2
  int _parent(int index) => (index - 1) ~/ 2;
  
  /// Get left child index in binary tree
  /// Left child of node at index i is at 2i+1
  int _leftChild(int index) => 2 * index + 1;
  
  /// Get right child index in binary tree
  /// Right child of node at index i is at 2i+2
  int _rightChild(int index) => 2 * index + 2;
  
  /// Swap two elements in the heap
  void _swap(int i, int j) {
    PrioritizedContact temp = _heap[i];
    _heap[i] = _heap[j];
    _heap[j] = temp;
  }
  
  /// Bubble up: Restore heap property upward
  /// 
  /// Called after insertion to move the new element to its correct position
  /// Compares with parent and swaps if smaller (min-heap property)
  /// 
  /// Time Complexity: O(log n) - Maximum height of tree
  void _bubbleUp(int index) {
    while (index > 0) {
      int parentIndex = _parent(index);
      
      // Min-heap property: parent should be smaller than child
      if (_heap[index].priorityScore < _heap[parentIndex].priorityScore) {
        _swap(index, parentIndex);
        index = parentIndex;
      } else {
        break;
      }
    }
  }
  
  /// Bubble down: Restore heap property downward
  /// 
  /// Called after extraction to move root replacement to correct position
  /// Compares with children and swaps with smallest child
  /// 
  /// Time Complexity: O(log n) - Maximum height of tree
  void _bubbleDown(int index) {
    while (true) {
      int smallest = index;
      int left = _leftChild(index);
      int right = _rightChild(index);
      
      // Check if left child is smaller
      if (left < _heap.length && 
          _heap[left].priorityScore < _heap[smallest].priorityScore) {
        smallest = left;
      }
      
      // Check if right child is smaller
      if (right < _heap.length && 
          _heap[right].priorityScore < _heap[smallest].priorityScore) {
        smallest = right;
      }
      
      // If smallest is not current index, swap and continue
      if (smallest != index) {
        _swap(index, smallest);
        index = smallest;
      } else {
        break;
      }
    }
  }
  
  /// Insert a contact into the priority queue
  /// 
  /// Process:
  /// 1. Add contact to end of heap
  /// 2. Bubble up to maintain min-heap property
  /// 
  /// Time Complexity: O(log n)
  /// 
  /// Parameters:
  /// - contact: Prioritized contact with score
  void insert(PrioritizedContact contact) {
    _heap.add(contact);
    _bubbleUp(_heap.length - 1);
  }
  
  /// Peek at the minimum priority contact (most urgent)
  /// 
  /// Returns the contact at the root without removing it
  /// 
  /// Time Complexity: O(1)
  /// 
  /// Returns: Contact with lowest priority score (highest urgency)
  PrioritizedContact? peek() {
    if (_heap.isEmpty) return null;
    return _heap[0];
  }
  
  /// Extract and remove the minimum priority contact
  /// 
  /// Process:
  /// 1. Save root element (minimum)
  /// 2. Move last element to root
  /// 3. Remove last element
  /// 4. Bubble down to restore heap property
  /// 
  /// Time Complexity: O(log n)
  /// 
  /// Returns: Contact with lowest priority score (highest urgency)
  PrioritizedContact? extractMin() {
    if (_heap.isEmpty) return null;
    
    if (_heap.length == 1) {
      return _heap.removeLast();
    }
    
    // Save minimum element
    PrioritizedContact min = _heap[0];
    
    // Move last element to root
    _heap[0] = _heap.removeLast();
    
    // Restore heap property
    _bubbleDown(0);
    
    return min;
  }
  
  /// Build priority queue from list of contacts
  /// 
  /// Inserts all contacts into the heap
  /// 
  /// Time Complexity: O(n log n) where n = number of contacts
  /// 
  /// Parameters:
  /// - contacts: List of prioritized contacts
  void buildHeap(List<PrioritizedContact> contacts) {
    _heap.clear();
    for (var contact in contacts) {
      insert(contact);
    }
  }
  
  /// Get all contacts in priority order (without modifying queue)
  /// 
  /// Creates a copy of the heap and extracts all elements
  /// 
  /// Time Complexity: O(n log n)
  /// 
  /// Returns: List of contacts ordered by priority (most urgent first)
  List<PrioritizedContact> toSortedList() {
    if (_heap.isEmpty) return [];
    
    // Create a copy to avoid modifying original heap
    ContactPriorityQueue copy = ContactPriorityQueue();
    copy._heap.addAll(_heap);
    
    List<PrioritizedContact> sorted = [];
    while (copy.isNotEmpty) {
      sorted.add(copy.extractMin()!);
    }
    
    return sorted;
  }
  
  /// Clear all contacts from the queue
  void clear() {
    _heap.clear();
  }
  
  /// Get statistics about the priority queue
  Map<String, dynamic> getStats() {
    if (_heap.isEmpty) {
      return {
        'size': 0,
        'min_score': null,
        'max_score': null,
        'avg_score': null,
      };
    }
    
    double minScore = _heap[0].priorityScore;
    double maxScore = _heap.map((c) => c.priorityScore).reduce((a, b) => a > b ? a : b);
    double avgScore = _heap.map((c) => c.priorityScore).reduce((a, b) => a + b) / _heap.length;
    
    return {
      'size': _heap.length,
      'min_score': minScore.toStringAsFixed(2),
      'max_score': maxScore.toStringAsFixed(2),
      'avg_score': avgScore.toStringAsFixed(2),
      'most_urgent': _heap[0].contactName,
    };
  }
}

/// Contact Priority Calculator
/// 
/// Calculates priority scores for contacts based on multiple factors:
/// 1. Days since last call (weight: 0.3)
/// 2. Call success rate (weight: 0.25)
/// 3. Average call rating (weight: 0.2)
/// 4. Total call attempts (weight: 0.15)
/// 5. Days since last successful call (weight: 0.1)
/// 
/// Priority Score Formula:
/// score = (days_weight × days_since_last_call) +
///         (success_weight × inverse_success_rate) +
///         (rating_weight × inverse_avg_rating) +
///         (attempts_weight × inverse_attempts) +
///         (success_days_weight × days_since_success)
/// 
/// Lower score = Higher priority (should be called sooner)
class ContactPriorityCalculator {
  final String userId;
  
  // Default weight factors for priority calculation
  static const double DEFAULT_DAYS_SINCE_CALL_WEIGHT = 0.3;
  static const double DEFAULT_SUCCESS_RATE_WEIGHT = 0.25;
  static const double DEFAULT_AVG_RATING_WEIGHT = 0.2;
  static const double DEFAULT_TOTAL_ATTEMPTS_WEIGHT = 0.15;
  static const double DEFAULT_DAYS_SINCE_SUCCESS_WEIGHT = 0.1;
  
  // Instance weight factors (configurable per user)
  late final double daysSinceCallWeight;
  late final double successRateWeight;
  late final double avgRatingWeight;
  late final double totalAttemptsWeight;
  late final double daysSinceSuccessWeight;
  
  // Maximum values for normalization
  static const int MAX_DAYS = 90;
  static const int MAX_ATTEMPTS = 20;
  
  ContactPriorityCalculator(this.userId, {Map<String, double>? weights}) {
    daysSinceCallWeight = weights?['days_since_call'] ?? DEFAULT_DAYS_SINCE_CALL_WEIGHT;
    successRateWeight = weights?['success_rate'] ?? DEFAULT_SUCCESS_RATE_WEIGHT;
    avgRatingWeight = weights?['avg_rating'] ?? DEFAULT_AVG_RATING_WEIGHT;
    totalAttemptsWeight = weights?['total_attempts'] ?? DEFAULT_TOTAL_ATTEMPTS_WEIGHT;
    daysSinceSuccessWeight = weights?['days_since_success'] ?? DEFAULT_DAYS_SINCE_SUCCESS_WEIGHT;
  }
  
  /// Load user-configured weights from Firebase
  static Future<Map<String, double>?> loadWeightsFromFirebase(String userId) async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('user_settings')
          .doc(userId)
          .get();
      
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (data.containsKey('auto_queue_weights')) {
          final weightsData = data['auto_queue_weights'] as Map<String, dynamic>;
          return {
            'days_since_call': (weightsData['days_since_call'] as num?)?.toDouble() ?? DEFAULT_DAYS_SINCE_CALL_WEIGHT,
            'success_rate': (weightsData['success_rate'] as num?)?.toDouble() ?? DEFAULT_SUCCESS_RATE_WEIGHT,
            'avg_rating': (weightsData['avg_rating'] as num?)?.toDouble() ?? DEFAULT_AVG_RATING_WEIGHT,
            'total_attempts': (weightsData['total_attempts'] as num?)?.toDouble() ?? DEFAULT_TOTAL_ATTEMPTS_WEIGHT,
            'days_since_success': (weightsData['days_since_success'] as num?)?.toDouble() ?? DEFAULT_DAYS_SINCE_SUCCESS_WEIGHT,
          };
        }
      }
      return null;
    } catch (e) {
      print('Error loading auto-queue weights: $e');
      return null;
    }
  }
  
  /// Save user-configured weights to Firebase
  static Future<void> saveWeightsToFirebase(String userId, Map<String, double> weights) async {
    try {
      await FirebaseFirestore.instance
          .collection('user_settings')
          .doc(userId)
          .set({
        'auto_queue_weights': weights,
        'auto_queue_weights_updated': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving auto-queue weights: $e');
    }
  }
  
  /// Get the default weights map
  static Map<String, double> get defaultWeights => {
    'days_since_call': DEFAULT_DAYS_SINCE_CALL_WEIGHT,
    'success_rate': DEFAULT_SUCCESS_RATE_WEIGHT,
    'avg_rating': DEFAULT_AVG_RATING_WEIGHT,
    'total_attempts': DEFAULT_TOTAL_ATTEMPTS_WEIGHT,
    'days_since_success': DEFAULT_DAYS_SINCE_SUCCESS_WEIGHT,
  };
  
  /// Calculate priority score for a contact
  /// 
  /// Lower score = Higher priority
  /// 
  /// Time Complexity: O(n) where n = number of calls for this contact
  /// 
  /// Parameters:
  /// - contactPhone: Phone number of contact
  /// - callHistory: List of all calls for this contact
  /// 
  /// Returns: Priority score (0-100 scale)
  Future<double> calculatePriority({
    required String contactPhone,
    required List<QueryDocumentSnapshot> callHistory,
  }) async {
    if (callHistory.isEmpty) {
      // New contact with no history = highest priority
      return 100.0;
    }
    
    // Extract call data
    DateTime now = DateTime.now();
    DateTime? lastCallDate;
    DateTime? lastSuccessfulCallDate;
    int totalCalls = callHistory.length;
    int successfulCalls = 0;
    double totalRating = 0.0;
    int ratedCalls = 0;
    
    for (var call in callHistory) {
      Map<String, dynamic> data = call.data() as Map<String, dynamic>;
      
      // Get timestamp
      if (data['timestamp'] != null) {
        DateTime callDate = (data['timestamp'] as Timestamp).toDate();
        
        if (lastCallDate == null || callDate.isAfter(lastCallDate)) {
          lastCallDate = callDate;
        }
        
        // Check if call was successful (answered)
        bool answered = data['answered'] == true;
        if (answered) {
          successfulCalls++;
          
          if (lastSuccessfulCallDate == null || callDate.isAfter(lastSuccessfulCallDate)) {
            lastSuccessfulCallDate = callDate;
          }
        }
        
        // Get rating
        int? rating = data['rating'] is int 
            ? data['rating'] 
            : (data['rating'] != null ? int.tryParse(data['rating'].toString()) : null);
        
        if (rating != null && rating > 0) {
          totalRating += rating;
          ratedCalls++;
        }
      }
    }
    
    // Calculate factors
    
    // 1. Days since last call (more days = higher priority)
    double daysSinceLastCall = lastCallDate != null
        ? now.difference(lastCallDate).inDays.toDouble()
        : MAX_DAYS.toDouble();
    double normalizedDays = (daysSinceLastCall / MAX_DAYS).clamp(0.0, 1.0);
    
    // 2. Success rate (lower success = higher priority)
    double successRate = totalCalls > 0 ? successfulCalls / totalCalls : 0.0;
    double inverseSuccessRate = 1.0 - successRate;
    
    // 3. Average rating (lower rating = higher priority)
    double avgRating = ratedCalls > 0 ? totalRating / ratedCalls : 3.0;
    double normalizedRating = 1.0 - (avgRating / 5.0); // Inverse normalize (0-1)
    
    // 4. Total attempts (fewer attempts = higher priority to establish relationship)
    double normalizedAttempts = 1.0 - (totalCalls / MAX_ATTEMPTS).clamp(0.0, 1.0);
    
    // 5. Days since last successful call
    double daysSinceSuccess = lastSuccessfulCallDate != null
        ? now.difference(lastSuccessfulCallDate).inDays.toDouble()
        : MAX_DAYS.toDouble();
    double normalizedSuccessDays = (daysSinceSuccess / MAX_DAYS).clamp(0.0, 1.0);
    
    // Calculate weighted priority score (0-100 scale)
    double score = (
      (daysSinceCallWeight * normalizedDays) +
      (successRateWeight * inverseSuccessRate) +
      (avgRatingWeight * normalizedRating) +
      (totalAttemptsWeight * normalizedAttempts) +
      (daysSinceSuccessWeight * normalizedSuccessDays)
    ) * 100;
    
    // Invert score so lower = higher priority
    // Contacts not called recently or with poor history get lower scores (higher priority)
    double finalScore = 100.0 - score;
    
    print('📊 Priority for $contactPhone: ${finalScore.toStringAsFixed(2)}');
    print('   Days since call: ${daysSinceLastCall.toInt()}');
    print('   Success rate: ${(successRate * 100).toStringAsFixed(0)}%');
    print('   Avg rating: ${avgRating.toStringAsFixed(1)}/5');
    print('   Total calls: $totalCalls');
    
    return finalScore;
  }
  
  /// Build priority queue from list of contacts
  /// 
  /// Fetches call history and calculates priority for each contact
  /// 
  /// Time Complexity: O(n × m) where n = contacts, m = avg calls per contact
  /// 
  /// Parameters:
  /// - contacts: List of contact data maps
  /// 
  /// Returns: ContactPriorityQueue with all contacts ordered by priority
  Future<ContactPriorityQueue> buildPriorityQueue(
    List<Map<String, dynamic>> contacts,
  ) async {
    ContactPriorityQueue queue = ContactPriorityQueue();
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    
    print('🔄 Building priority queue for ${contacts.length} contacts...');
    
    for (var contact in contacts) {
      String phoneNumber = contact['contact_phone_number'] ?? '';
      
      if (phoneNumber.isEmpty) continue;
      
      // Fetch call history for this contact
      QuerySnapshot callHistory = await firestore
          .collection('call_history')
          .where('address', isEqualTo: phoneNumber)
          .get();
      
      // Calculate priority score
      double score = await calculatePriority(
        contactPhone: phoneNumber,
        callHistory: callHistory.docs,
      );
      
      // Insert into priority queue
      queue.insert(PrioritizedContact(
        contactData: contact,
        priorityScore: score,
      ));
    }
    
    print('✅ Priority queue built: ${queue.getStats()}');
    
    return queue;
  }
  
  /// Get description of priority factors for UI display
  static String getPriorityFactorsDescription({Map<String, double>? weights}) {
    final w = weights ?? defaultWeights;
    return '''Time since last call (${((w['days_since_call'] ?? DEFAULT_DAYS_SINCE_CALL_WEIGHT) * 100).toInt()}%), Success rate (${((w['success_rate'] ?? DEFAULT_SUCCESS_RATE_WEIGHT) * 100).toInt()}%), Call ratings (${((w['avg_rating'] ?? DEFAULT_AVG_RATING_WEIGHT) * 100).toInt()}%), Relationship depth (${((w['total_attempts'] ?? DEFAULT_TOTAL_ATTEMPTS_WEIGHT) * 100).toInt()}%), Follow-up urgency (${((w['days_since_success'] ?? DEFAULT_DAYS_SINCE_SUCCESS_WEIGHT) * 100).toInt()}%)''';
  }
}
