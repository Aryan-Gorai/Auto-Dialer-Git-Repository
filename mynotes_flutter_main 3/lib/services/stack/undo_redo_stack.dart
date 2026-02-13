// Generic Undo/Redo Stack — a classic stack data structure that
// supports push, pop, peek, and isEmpty operations, extended with
// a secondary redo stack for bidirectional history navigation.
//
// Used in the contact notes editor to allow users to undo/redo
// text changes, with optional Firestore persistence of edit history.
//
// Implements:
//   • Array-backed stack with push / pop / peek
//   • Undo/redo semantics (dual-stack pattern)
//   • Firestore integration for edit-history audit trail
//
// AQA Group A: Stacks, Stack operations (push/pop/peek)

import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// Generic undo/redo stack
// ---------------------------------------------------------------------------

/// A generic undo/redo stack backed by two internal lists (array-backed
/// stacks).  Pushing a new item clears the redo stack — the standard
/// behaviour for undo/redo systems in text editors, drawing apps, etc.
///
/// Time complexity:
///   push  — O(1) amortised
///   undo  — O(1)
///   redo  — O(1)
///   peek  — O(1)
class UndoRedoStack<T> {
  final List<T> _undoStack = [];
  final List<T> _redoStack = [];

  /// Optional maximum depth.  When set, the oldest undo entries are
  /// discarded once the stack exceeds this size (prevents unbounded
  /// memory growth for long editing sessions).
  final int? maxDepth;

  UndoRedoStack({this.maxDepth});

  // ---- Stack operations ----

  /// Push a new item onto the undo stack.
  /// Clears the redo stack (standard editor behaviour — any new edit
  /// after an undo invalidates the previous redo history).
  void push(T item) {
    _undoStack.add(item);
    _redoStack.clear();

    // Enforce depth limit by removing the oldest entry.
    if (maxDepth != null && _undoStack.length > maxDepth!) {
      _undoStack.removeAt(0);
    }
  }

  /// Pop the most recent item from the undo stack and move it to the
  /// redo stack.  Returns the item that was undone, or null if the
  /// undo stack is empty.
  T? undo() {
    if (_undoStack.isEmpty) return null;
    final item = _undoStack.removeLast();
    _redoStack.add(item);
    return item;
  }

  /// Pop the most recent item from the redo stack and move it back
  /// to the undo stack.  Returns the re-applied item, or null if
  /// the redo stack is empty.
  T? redo() {
    if (_redoStack.isEmpty) return null;
    final item = _redoStack.removeLast();
    _undoStack.add(item);
    return item;
  }

  /// View the top of the undo stack without removing it.
  T? peek() {
    if (_undoStack.isEmpty) return null;
    return _undoStack.last;
  }

  /// View the top of the redo stack without removing it.
  T? peekRedo() {
    if (_redoStack.isEmpty) return null;
    return _redoStack.last;
  }

  // ---- State queries ----

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get isEmpty => _undoStack.isEmpty && _redoStack.isEmpty;

  int get undoDepth => _undoStack.length;
  int get redoDepth => _redoStack.length;

  /// Returns a copy of the full undo history (oldest first).
  List<T> get undoHistory => List.unmodifiable(_undoStack);

  /// Returns a copy of the full redo history (oldest first).
  List<T> get redoHistory => List.unmodifiable(_redoStack);

  /// Clear both stacks entirely.
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }

  @override
  String toString() =>
      'UndoRedoStack(undoDepth=$undoDepth, redoDepth=$redoDepth)';
}

// ---------------------------------------------------------------------------
// Specialised text-edit snapshot for note editing
// ---------------------------------------------------------------------------

/// Immutable snapshot of a note's text content at a point in time.
/// Stored on the [UndoRedoStack] and optionally persisted to Firestore.
class NoteEditSnapshot {
  final String text;
  final DateTime timestamp;
  final int cursorPosition;

  const NoteEditSnapshot({
    required this.text,
    required this.timestamp,
    this.cursorPosition = 0,
  });

  /// Serialise to a map suitable for Firestore storage.
  Map<String, dynamic> toFirestore() => {
        'text': text,
        'timestamp': Timestamp.fromDate(timestamp),
        'cursor_position': cursorPosition,
      };

  /// Deserialise from a Firestore document map.
  factory NoteEditSnapshot.fromFirestore(Map<String, dynamic> data) {
    return NoteEditSnapshot(
      text: (data['text'] ?? '') as String,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      cursorPosition: (data['cursor_position'] ?? 0) as int,
    );
  }

  @override
  String toString() =>
      'NoteEditSnapshot(len=${text.length}, cursor=$cursorPosition)';
}

// ---------------------------------------------------------------------------
// Firestore-backed edit history
// ---------------------------------------------------------------------------

/// Persists the edit history of a contact note to Firestore as a
/// subcollection.  This creates an immutable audit trail of changes.
class NoteEditHistoryService {
  static const String _contactNotesCollection = 'contact_notes';
  static const String _editHistorySubcollection = 'edit_history';

  /// Save a snapshot to the edit_history subcollection of a note.
  static Future<void> saveSnapshot({
    required String noteDocId,
    required NoteEditSnapshot snapshot,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection(_contactNotesCollection)
          .doc(noteDocId)
          .collection(_editHistorySubcollection)
          .add(snapshot.toFirestore());
    } catch (e) {
      // Non-fatal — edit history is supplementary.
      // ignore: avoid_print
      print('Failed to save edit history snapshot: $e');
    }
  }

  /// Load the full edit history for a note, ordered chronologically.
  static Future<List<NoteEditSnapshot>> loadHistory(String noteDocId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_contactNotesCollection)
          .doc(noteDocId)
          .collection(_editHistorySubcollection)
          .orderBy('timestamp', descending: false)
          .get();

      return snapshot.docs
          .map((doc) =>
              NoteEditSnapshot.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }
}
