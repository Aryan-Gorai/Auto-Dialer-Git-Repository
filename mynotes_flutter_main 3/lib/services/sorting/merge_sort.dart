// Merge Sort — a recursive divide-and-conquer sorting algorithm
// with O(n log n) time complexity in all cases and O(n) auxiliary
// space.  This is a hand-coded implementation — not a wrapper
// around Dart's built-in .sort().
//
// Implements:
//   • Generic mergeSort<T> with a custom comparator
//   • Recursive divide at midpoint
//   • Linear-time merge of two sorted sublists
//   • Specialised mergeSortContacts for PrioritizedContact objects
//
// AQA Group A: Mergesort or similarly efficient sort,
//              Recursive algorithms

import 'package:flutter_application_1/services/priority_queue/contact_priority_queue.dart';

// ---------------------------------------------------------------------------
// Generic merge sort
// ---------------------------------------------------------------------------

/// Sorts a list of [T] using the merge sort algorithm.
///
/// Parameters:
///   [list]    — the input list to sort (not modified in place)
///   [compare] — comparator function; returns negative if a < b,
///               zero if equal, positive if a > b
///
/// Returns a new sorted list.  The original list is unchanged.
///
/// Time complexity:  O(n log n) — worst, average, and best case
/// Space complexity: O(n) — auxiliary space for merge buffers
List<T> mergeSort<T>(List<T> list, int Function(T a, T b) compare) {
  // Base case: a list of 0 or 1 elements is already sorted.
  if (list.length <= 1) return List<T>.from(list);

  // Divide: split the list at the midpoint.
  final int mid = list.length ~/ 2;
  final List<T> left = list.sublist(0, mid);
  final List<T> right = list.sublist(mid);

  // Conquer: recursively sort each half.
  final List<T> sortedLeft = mergeSort(left, compare);
  final List<T> sortedRight = mergeSort(right, compare);

  // Combine: merge the two sorted halves.
  return _merge(sortedLeft, sortedRight, compare);
}

/// Merges two sorted lists into a single sorted list — O(n).
///
/// Uses two pointers (i and j) that advance through the left and
/// right sublists respectively.  At each step the smaller element
/// is appended to the result.
List<T> _merge<T>(
    List<T> left, List<T> right, int Function(T a, T b) compare) {
  final result = <T>[];
  int i = 0; // pointer into left
  int j = 0; // pointer into right

  // Compare elements from both halves and take the smaller one.
  while (i < left.length && j < right.length) {
    if (compare(left[i], right[j]) <= 0) {
      result.add(left[i]);
      i++;
    } else {
      result.add(right[j]);
      j++;
    }
  }

  // Append any remaining elements from the left half.
  while (i < left.length) {
    result.add(left[i]);
    i++;
  }

  // Append any remaining elements from the right half.
  while (j < right.length) {
    result.add(right[j]);
    j++;
  }

  return result;
}

// ---------------------------------------------------------------------------
// Specialised: sort PrioritizedContact by priority score
// ---------------------------------------------------------------------------

/// Sorts a list of [PrioritizedContact] objects by their priority
/// score (ascending — lower score = higher priority) using merge sort.
///
/// This is an alternative to the heap-sort provided by
/// [ContactPriorityQueue.toSortedList], demonstrating a second
/// O(n log n) sorting algorithm.
List<PrioritizedContact> mergeSortContacts(
    List<PrioritizedContact> contacts) {
  return mergeSort<PrioritizedContact>(
    contacts,
    (a, b) => a.priorityScore.compareTo(b.priorityScore),
  );
}

/// Sorts contacts by name alphabetically using merge sort.
List<PrioritizedContact> mergeSortContactsByName(
    List<PrioritizedContact> contacts) {
  return mergeSort<PrioritizedContact>(
    contacts,
    (a, b) => a.contactName.toLowerCase().compareTo(
          b.contactName.toLowerCase(),
        ),
  );
}

// ---------------------------------------------------------------------------
// Generic: sort any list of maps by a string key
// ---------------------------------------------------------------------------

/// Merge-sorts a list of maps by a given string key.
/// Useful for sorting Firestore document data without converting
/// to typed objects first.
List<Map<String, dynamic>> mergeSortMaps(
  List<Map<String, dynamic>> maps,
  String key, {
  bool descending = false,
}) {
  return mergeSort<Map<String, dynamic>>(
    maps,
    (a, b) {
      final aVal = a[key]?.toString() ?? '';
      final bVal = b[key]?.toString() ?? '';
      final result = aVal.compareTo(bVal);
      return descending ? -result : result;
    },
  );
}

/// Merge-sorts a list of maps by a numeric key.
List<Map<String, dynamic>> mergeSortMapsByNumber(
  List<Map<String, dynamic>> maps,
  String key, {
  bool descending = false,
}) {
  return mergeSort<Map<String, dynamic>>(
    maps,
    (a, b) {
      final aVal = (a[key] is num) ? (a[key] as num).toDouble() : 0.0;
      final bVal = (b[key] is num) ? (b[key] as num).toDouble() : 0.0;
      final result = aVal.compareTo(bVal);
      return descending ? -result : result;
    },
  );
}
