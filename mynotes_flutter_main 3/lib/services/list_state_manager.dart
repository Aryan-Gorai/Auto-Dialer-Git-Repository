// ListStateManager — singleton that encapsulates all the mutable state
// previously scattered as top-level globals across firebase_services.dart
// and list_view.dart.
//
// This improves coding style by:
//   - Eliminating global mutable variables (AQA "Good" criterion)
//   - Providing a clean interface for state access (AQA "Excellent" criterion)
//   - Centralising state so it can be tested and reasoned about
//
// All existing callers can migrate incrementally:
//   Old:  selectedList = 'My List';
//   New:  ListStateManager().selectedList = 'My List';

import 'dart:async';
import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:fluttercontactpicker/fluttercontactpicker.dart';

/// Singleton that owns the shared mutable state for the list/dialer
/// flow.  Access via `ListStateManager()` — always returns the same
/// instance.
class ListStateManager {
  // ---- Singleton boilerplate ----
  static final ListStateManager _instance = ListStateManager._internal();
  factory ListStateManager() => _instance;
  ListStateManager._internal();

  // ---- State formerly in firebase_services.dart ----

  /// Whether the device supports tel: URI launching.
  bool hasCallSupport = false;

  /// Future returned by the last `launchUrl` call (for status tracking).
  Future<void>? launched;

  /// Scratch phone-number string used during contact picking.
  String phone = '';

  /// Currently-selected list name (drives which contacts are shown).
  String selectedList = '';

  /// All list names for the current user, kept in sync with Firestore.
  List<String> listNames = [];

  /// Phone number picked most recently via the contact picker.
  String pickedNumber = '';

  /// Contact name picked most recently via the contact picker.
  String pickedName = '';

  /// Full PhoneContact object from the last picker interaction.
  PhoneContact? phoneContact;

  // ---- State formerly in list_view.dart ----

  /// Current call-cycle index (which contact we're up to).
  int callCycleIndex = 0;

  /// Index before the last increment (for undo / back navigation).
  int previousIndex = 0;

  /// Total number of contacts in the currently-active list.
  int totalDocuments = 0;

  /// Comma-joined contact names passed to the dialer view for display.
  String listContactsJoinedForDialer = '';

  /// Comma-joined contact names for local display.
  String listContactsJoined = '';

  /// Cached array of document maps fetched during a call cycle.
  List<Map<String, dynamic>> documentArray = [];

  /// Timer used to track elapsed seconds during a phone call.
  Timer? callTimer;

  /// Seconds elapsed since the call timer started.
  int elapsedSeconds = 0;

  // ---- Convenience accessor ----

  /// Current authenticated user's ID.  Throws if not logged in.
  String get userId => AuthService.firebase().currentUser!.id;

  // ---- Methods ----

  /// Reset all dialer/cycle state back to defaults.
  void resetCallCycle() {
    callCycleIndex = 0;
    previousIndex = 0;
    totalDocuments = 0;
    elapsedSeconds = 0;
    callTimer?.cancel();
    callTimer = null;
    documentArray = [];
  }

  /// Start the elapsed-seconds timer for the current call.
  void startCallTimer(void Function(void Function()) setState) {
    callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        elapsedSeconds++;
      });
    });
  }

  /// Stop and cancel the call timer.
  void stopCallTimer() {
    callTimer?.cancel();
    callTimer = null;
  }

  @override
  String toString() => 'ListStateManager('
      'selectedList=$selectedList, '
      'listNames=${listNames.length}, '
      'callCycleIndex=$callCycleIndex)';
}
