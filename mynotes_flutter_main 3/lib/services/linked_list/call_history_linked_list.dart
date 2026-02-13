// Doubly-Linked List — maintains a contact's call history in
// chronological order, supporting O(1) insertion at head/tail
// and bidirectional traversal.
//
// Implements:
//   • Doubly-linked list with head/tail pointers
//   • insertAtHead / insertAtTail — O(1)
//   • deleteNode — O(1) with pointer rewiring
//   • forward and reverse traversal
//   • linear search by phone number
//   • Firestore integration — builds from call_history collection
//
// AQA Group A: Linked list maintenance, List operations

import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// Node class
// ---------------------------------------------------------------------------

/// A single node in the doubly-linked call history list.
/// Holds a call record (as a map) plus pointers to the
/// previous and next nodes.
class CallHistoryNode {
  final Map<String, dynamic> callData;
  CallHistoryNode? next;
  CallHistoryNode? prev;

  CallHistoryNode({
    required this.callData,
    this.next,
    this.prev,
  });

  /// Convenience accessors for common call fields.
  String get phoneNumber => (callData['address'] ?? '') as String;
  String get contactName => (callData['contact_name'] ?? '') as String;
  int get duration => (callData['duration'] ?? 0) as int;
  bool get answered => (callData['answered'] ?? false) as bool;

  DateTime? get timestamp {
    final ts = callData['timestamp'];
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return null;
  }

  @override
  String toString() =>
      'CallHistoryNode($phoneNumber, ${timestamp?.toIso8601String()})';
}

// ---------------------------------------------------------------------------
// Doubly-linked list
// ---------------------------------------------------------------------------

/// A doubly-linked list of call history records, ordered
/// chronologically (head = newest, tail = oldest by default).
///
/// Supports O(1) insertion at either end, O(1) deletion of any
/// node given a reference, and O(n) search/traversal.
class CallHistoryLinkedList {
  CallHistoryNode? _head;
  CallHistoryNode? _tail;
  int _length = 0;

  // ---- Accessors ----

  CallHistoryNode? get head => _head;
  CallHistoryNode? get tail => _tail;
  int get length => _length;
  bool get isEmpty => _length == 0;

  // ---- Insertion ----

  /// Insert a new call record at the head (front) of the list — O(1).
  /// Typically used for the most recent call.
  CallHistoryNode insertAtHead(Map<String, dynamic> callData) {
    final newNode = CallHistoryNode(callData: callData);

    if (_head == null) {
      // List is empty — new node is both head and tail.
      _head = newNode;
      _tail = newNode;
    } else {
      newNode.next = _head;
      _head!.prev = newNode;
      _head = newNode;
    }

    _length++;
    return newNode;
  }

  /// Insert a new call record at the tail (end) of the list — O(1).
  /// Typically used when loading historical calls in chronological order.
  CallHistoryNode insertAtTail(Map<String, dynamic> callData) {
    final newNode = CallHistoryNode(callData: callData);

    if (_tail == null) {
      _head = newNode;
      _tail = newNode;
    } else {
      newNode.prev = _tail;
      _tail!.next = newNode;
      _tail = newNode;
    }

    _length++;
    return newNode;
  }

  /// Insert a new node after a given existing node — O(1).
  CallHistoryNode insertAfter(
      CallHistoryNode existingNode, Map<String, dynamic> callData) {
    final newNode = CallHistoryNode(callData: callData);

    newNode.prev = existingNode;
    newNode.next = existingNode.next;

    if (existingNode.next != null) {
      existingNode.next!.prev = newNode;
    } else {
      // existingNode was the tail — update tail pointer.
      _tail = newNode;
    }
    existingNode.next = newNode;

    _length++;
    return newNode;
  }

  // ---- Deletion ----

  /// Delete a specific node from the list — O(1).
  /// Rewires the prev/next pointers of neighbouring nodes.
  void deleteNode(CallHistoryNode node) {
    if (node.prev != null) {
      node.prev!.next = node.next;
    } else {
      // node was the head — advance the head pointer.
      _head = node.next;
    }

    if (node.next != null) {
      node.next!.prev = node.prev;
    } else {
      // node was the tail — retreat the tail pointer.
      _tail = node.prev;
    }

    // Null out the deleted node's pointers to avoid dangling refs.
    node.prev = null;
    node.next = null;
    _length--;
  }

  /// Remove and return the head node — O(1).
  CallHistoryNode? removeHead() {
    if (_head == null) return null;
    final removed = _head!;
    deleteNode(removed);
    return removed;
  }

  /// Remove and return the tail node — O(1).
  CallHistoryNode? removeTail() {
    if (_tail == null) return null;
    final removed = _tail!;
    deleteNode(removed);
    return removed;
  }

  // ---- Traversal ----

  /// Forward traversal: head → tail (newest → oldest).
  /// Returns call data maps in order.
  List<Map<String, dynamic>> traverse() {
    final result = <Map<String, dynamic>>[];
    CallHistoryNode? current = _head;
    while (current != null) {
      result.add(current.callData);
      current = current.next;
    }
    return result;
  }

  /// Reverse traversal: tail → head (oldest → newest).
  List<Map<String, dynamic>> reverseTraverse() {
    final result = <Map<String, dynamic>>[];
    CallHistoryNode? current = _tail;
    while (current != null) {
      result.add(current.callData);
      current = current.prev;
    }
    return result;
  }

  /// Iterate forward, calling [visitor] for each node.
  /// If [visitor] returns false, traversal stops early.
  void forEachNode(bool Function(CallHistoryNode node) visitor) {
    CallHistoryNode? current = _head;
    while (current != null) {
      if (!visitor(current)) return;
      current = current.next;
    }
  }

  // ---- Search ----

  /// Linear search for the first node matching [phoneNumber] — O(n).
  CallHistoryNode? search(String phoneNumber) {
    CallHistoryNode? current = _head;
    while (current != null) {
      if (_normalizePhone(current.phoneNumber) ==
          _normalizePhone(phoneNumber)) {
        return current;
      }
      current = current.next;
    }
    return null;
  }

  /// Find all nodes matching [phoneNumber] — O(n).
  List<CallHistoryNode> searchAll(String phoneNumber) {
    final results = <CallHistoryNode>[];
    CallHistoryNode? current = _head;
    while (current != null) {
      if (_normalizePhone(current.phoneNumber) ==
          _normalizePhone(phoneNumber)) {
        results.add(current);
      }
      current = current.next;
    }
    return results;
  }

  // ---- Utilities ----

  /// Serialise the entire list to a flat list of maps (head→tail order).
  List<Map<String, dynamic>> toList() => traverse();

  /// Get the node at a specific zero-based index — O(n).
  CallHistoryNode? getAtIndex(int index) {
    if (index < 0 || index >= _length) return null;
    CallHistoryNode? current = _head;
    for (int i = 0; i < index; i++) {
      current = current?.next;
    }
    return current;
  }

  /// Count of calls matching a phone number — O(n).
  int countCallsForPhone(String phoneNumber) {
    return searchAll(phoneNumber).length;
  }

  /// Total call duration across all entries — O(n).
  int get totalDuration {
    int total = 0;
    forEachNode((node) {
      total += node.duration;
      return true; // continue
    });
    return total;
  }

  /// Clear the entire list.
  void clear() {
    _head = null;
    _tail = null;
    _length = 0;
  }

  /// Normalise a phone number to last 9 digits for matching.
  static String _normalizePhone(String input) {
    final digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length <= 9) return digitsOnly;
    return digitsOnly.substring(digitsOnly.length - 9);
  }

  @override
  String toString() =>
      'CallHistoryLinkedList(length=$_length, '
      'head=${_head?.phoneNumber}, tail=${_tail?.phoneNumber})';

  // ---- Firestore integration ----

  /// Builds a linked list from the user's call_history collection,
  /// optionally filtered to a specific contact phone number.
  /// Calls are inserted in chronological order (oldest at tail,
  /// newest at head).
  static Future<CallHistoryLinkedList> buildFromFirestore({
    required String userId,
    String? contactPhone,
  }) async {
    final linkedList = CallHistoryLinkedList();

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('call_history')
        .where('user_id', isEqualTo: userId)
        .orderBy('timestamp', descending: false);

    final snapshot = await query.get();

    final normalizedFilter = contactPhone != null
        ? _normalizePhone(contactPhone)
        : null;

    for (final doc in snapshot.docs) {
      final data = doc.data();

      // If filtering by phone, skip non-matching records.
      if (normalizedFilter != null) {
        final address = (data['address'] ?? '') as String;
        if (_normalizePhone(address) != normalizedFilter) continue;
      }

      // Insert at tail so that chronological order is preserved
      // (oldest first → newest last → newest becomes head after
      // we reverse conceptually, or we just read tail→head).
      linkedList.insertAtTail({...data, 'doc_id': doc.id});
    }

    return linkedList;
  }

  /// Persist the linked-list order back to Firestore by updating
  /// an `order_index` field on each call_history document.
  Future<void> persistOrderToFirestore() async {
    int index = 0;
    CallHistoryNode? current = _head;
    final batch = FirebaseFirestore.instance.batch();

    while (current != null) {
      final docId = current.callData['doc_id'];
      if (docId != null && docId is String) {
        batch.update(
          FirebaseFirestore.instance.collection('call_history').doc(docId),
          {'order_index': index},
        );
      }
      index++;
      current = current.next;
    }

    await batch.commit();
  }
}
