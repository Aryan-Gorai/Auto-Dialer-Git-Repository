import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter_application_1/services/call_cycle_service.dart';
import 'package:flutter_application_1/services/nlp/nlp_service.dart';
import 'package:flutter_application_1/services/priority_queue/contact_priority_queue.dart';
import 'package:flutter_application_1/views/list/firebase_services.dart';
import 'package:flutter_application_1/views/notes/contact_notes_view.dart';
import 'package:flutter_application_1/utilities/dialogs/call_feedback_dialog.dart';
import 'package:flutter_application_1/utilities/apple_typography.dart';


class ImgSample {
  static String get(String imageName) {
    return "asses/image/$imageName";
  }
}




class MyStringsSample {
  static const String card_text =
      "This is a sample card description. You can replace it with your own text.";
}

class MyColorsSample {
  static const Color accent = Colors.blue; // Replace with your desired color
}







class DialerContactsView extends StatefulWidget {
  final String listName;

  const DialerContactsView({Key? key, required this.listName}) : super(key: key);

  @override
  State<DialerContactsView> createState() => _DialerContactsViewState();
}

class _DialerContactsViewState extends State<DialerContactsView> with WidgetsBindingObserver {
  List<String> myTiles = [];
  bool isLoading = true;
  int currentCallIndex = -1; // Track the currently called contact
  List<Map<String, dynamic>> contactsData = []; // Store full contact data
  DateTime? callStartTime;
  Duration callDuration = Duration.zero;
  Timer? callTimer;
  late TextEditingController _descriptionController;
  String? _listDescription;
  bool showFeedbackDialogEnabled = true; // Track if feedback dialogs should be shown
  bool autoCycleEnabled = false; // Track if auto-cycle to next contact is enabled
  bool autoQueueEnabled = false; // Track if priority queue auto-ordering is enabled
  List<Map<String, dynamic>> _originalContactOrder = []; // Store original user order
  bool _isInCall = false; // Track if user is currently in a call
  Timer? _autoCycleTimer; // Timer for delayed auto-cycle after app resume
  bool isPaused = false; // Track if auto-cycle is paused
  bool isSettingsExpanded = false; // Track if settings section is expanded

  // Call Cycle Tracking
  String? _activeCycleId; // Current cycle document ID
  String? _currentEventId; // Current call intent event ID
  bool _isReconciling = false; // Track if reconciliation is in progress

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _descriptionController = TextEditingController();
    fetchListDescription();
    loadFeedbackDialogSetting();
    loadAutoCycleSetting();
    loadAutoQueueSetting();
    fetchContactsAsArray(widget.listName).then((contacts) async {
      setState(() {
        myTiles = contacts;
        isLoading = false;
      });
      await updateContactIndices();
      await fetchContactsData();
      // Check for saved progress AFTER contacts data is fully loaded
      await Future.delayed(Duration(milliseconds: 300));
      if (mounted) {
        await checkAndOfferResume();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused) {
      // User left the app (likely to take a call)
      _isInCall = true;
      print('📱 App paused - user likely in a call');
    } else if (state == AppLifecycleState.resumed && _isInCall && autoCycleEnabled && !isPaused && currentCallIndex >= 0) {
      // User returned to the app after being in a call AND there's an active cycle
      print('📱 App resumed - auto-cycling to next contact in 2 seconds...');
      _isInCall = false;
      
      // Wait 2 seconds before auto-cycling to give user time to see what's happening
      _autoCycleTimer?.cancel();
      _autoCycleTimer = Timer(Duration(seconds: 2), () {
        if (mounted && autoCycleEnabled && !isPaused && currentCallIndex >= 0) {
          print('🔄 Auto-cycling to next contact now');
          moveToNextContact();
        }
      });
    } else if (state == AppLifecycleState.resumed) {
      _isInCall = false;
    }
  }

  Future<void> fetchListDescription() async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot snapshot = await firestore
          .collection('lists_collection')
          .where('list_name', isEqualTo: widget.listName)
          .where('user_id', isEqualTo: userId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _listDescription = snapshot.docs.first['description'] as String?;
          _descriptionController.text = _listDescription ?? '';
        });
      }
    } catch (e) {
      print('Error getting description: $e');
    }
  }

  Future<void> loadFeedbackDialogSetting() async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot snapshot = await firestore
          .collection('lists_collection')
          .where('list_name', isEqualTo: widget.listName)
          .where('user_id', isEqualTo: userId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          // Default to true if the field doesn't exist
          showFeedbackDialogEnabled = snapshot.docs.first['show_feedback_dialog'] as bool? ?? true;
        });
      }
    } catch (e) {
      print('Error loading feedback dialog setting: $e');
    }
  }

  Future<void> loadAutoCycleSetting() async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot snapshot = await firestore
          .collection('lists_collection')
          .where('list_name', isEqualTo: widget.listName)
          .where('user_id', isEqualTo: userId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          // Default to false if the field doesn't exist
          autoCycleEnabled = snapshot.docs.first['auto_cycle_enabled'] as bool? ?? false;
        });
      }
    } catch (e) {
      print('Error loading auto-cycle setting: $e');
    }
  }

  Future<void> loadAutoQueueSetting() async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot snapshot = await firestore
          .collection('lists_collection')
          .where('list_name', isEqualTo: widget.listName)
          .where('user_id', isEqualTo: userId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          // Default to false if the field doesn't exist
          autoQueueEnabled = snapshot.docs.first['auto_queue_enabled'] as bool? ?? false;
        });
      }
    } catch (e) {
      print('Error loading auto queue setting: $e');
    }
  }

  Future<void> saveProgressToFirestore(int index) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot snapshot = await firestore
          .collection('lists_collection')
          .where('list_name', isEqualTo: widget.listName)
          .where('user_id', isEqualTo: userId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({
          'current_call_index': index,
          'is_paused': isPaused,
          'last_updated': Timestamp.now(),
        });
        print('💾 Progress saved: Contact ${index + 1} of ${contactsData.length}, Paused: $isPaused');
      }
    } catch (e) {
      print('Error saving progress: $e');
    }
  }

  Future<Map<String, dynamic>?> loadSavedProgress() async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot snapshot = await firestore
          .collection('lists_collection')
          .where('list_name', isEqualTo: widget.listName)
          .where('user_id', isEqualTo: userId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        int? savedIndex = snapshot.docs.first['current_call_index'] as int?;
        bool? wasPaused = snapshot.docs.first['is_paused'] as bool?;
        if (savedIndex != null && savedIndex >= 0) {
          print('📂 Found saved progress: Contact ${savedIndex + 1}, Was paused: ${wasPaused ?? false}');
          return {
            'index': savedIndex,
            'is_paused': wasPaused ?? false,
          };
        }
      }
    } catch (e) {
      print('Error loading saved progress: $e');
    }
    return null;
  }

  Future<void> clearSavedProgress() async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot snapshot = await firestore
          .collection('lists_collection')
          .where('list_name', isEqualTo: widget.listName)
          .where('user_id', isEqualTo: userId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({
          'current_call_index': -1,
        });
        print('🗑️ Saved progress cleared');
      }
    } catch (e) {
      print('Error clearing saved progress: $e');
    }
  }

  Future<void> checkAndOfferResume() async {
    print('🔍 Checking for saved progress...');
    print('📊 Contacts data length: ${contactsData.length}');
    
    if (contactsData.isEmpty) {
      print('⚠️ No contacts loaded yet, skipping resume check');
      return;
    }
    
    Map<String, dynamic>? savedProgress = await loadSavedProgress();
    
    if (savedProgress != null) {
      int savedIndex = savedProgress['index'] as int;
      bool wasPaused = savedProgress['is_paused'] as bool;
      
      print('📍 Saved index: $savedIndex, Was paused: $wasPaused, Contacts length: ${contactsData.length}');
      
      if (savedIndex >= 0 && savedIndex < contactsData.length) {
        // Show dialog asking if user wants to resume
        if (mounted) {
          bool? shouldResume = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.restore, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Resume Call Cycle?'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wasPaused 
                        ? 'You have a paused call cycle for this list.'
                        : 'You have a call cycle in progress for this list.',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (wasPaused ? Colors.orange : Colors.blue).shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: (wasPaused ? Colors.orange : Colors.blue).shade200),
                    ),
                    child: Column(
                      children: [
                        if (wasPaused)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Icon(Icons.pause_circle, color: Colors.orange, size: 20),
                                SizedBox(width: 6),
                                Text(
                                  'Paused',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Last position:',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Text(
                              'Contact ${savedIndex + 1} of ${contactsData.length}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: (wasPaused ? Colors.orange : Colors.blue).shade900,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        if (savedIndex < contactsData.length) ...[
                          SizedBox(height: 8),
                          Text(
                            contactsData[savedIndex]['contact_name'],
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Would you like to continue from where you left off?',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: Text(
                    'Start Fresh',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: wasPaused ? Colors.orange : Colors.blue,
                  ),
                  child: Text('Resume'),
                ),
              ],
            ),
          );

          if (shouldResume == true && mounted) {
            setState(() {
              currentCallIndex = savedIndex;
              isPaused = wasPaused;
            });
            print('▶️ Resumed call cycle at contact ${savedIndex + 1}, Paused: $wasPaused');
            
            // Automatically dial the current contact if not paused
            if (!wasPaused) {
              await Future.delayed(Duration(milliseconds: 500));
              if (mounted) {
                callCurrentContact();
              }
            }
          } else {
            // User chose to start fresh, clear saved progress
            await clearSavedProgress();
          }
        }
      }
    }
  }

  Future<void> toggleFeedbackDialog(bool enabled) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot snapshot = await firestore
          .collection('lists_collection')
          .where('list_name', isEqualTo: widget.listName)
          .where('user_id', isEqualTo: userId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({
          'show_feedback_dialog': enabled,
        });
        setState(() {
          showFeedbackDialogEnabled = enabled;
        });
        print('Feedback dialog ${enabled ? 'enabled' : 'disabled'} for list: ${widget.listName}');
      }
    } catch (e) {
      print('Error toggling feedback dialog: $e');
    }
  }

  Future<void> toggleAutoCycle(bool enabled) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot snapshot = await firestore
          .collection('lists_collection')
          .where('list_name', isEqualTo: widget.listName)
          .where('user_id', isEqualTo: userId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({
          'auto_cycle_enabled': enabled,
        });
        setState(() {
          autoCycleEnabled = enabled;
        });
        print('Auto-cycle ${enabled ? 'enabled' : 'disabled'} for list: ${widget.listName}');
      }
    } catch (e) {
      print('Error toggling auto-cycle: $e');
    }
  }

  Future<void> toggleAutoQueue(bool enabled) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot snapshot = await firestore
          .collection('lists_collection')
          .where('list_name', isEqualTo: widget.listName)
          .where('user_id', isEqualTo: userId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({
          'auto_queue_enabled': enabled,
        });
        setState(() {
          autoQueueEnabled = enabled;
        });
        
        // Apply priority ordering when enabled, restore original when disabled
        if (enabled && contactsData.isNotEmpty) {
          // Save original order before applying priority
          _originalContactOrder = List.from(contactsData);
          await _applyPriorityOrdering();
        } else if (!enabled && _originalContactOrder.isNotEmpty) {
          // Restore original user-defined order
          setState(() {
            contactsData = List.from(_originalContactOrder);
            // Update myTiles to match contactsData order
            myTiles = contactsData.map((c) => c['contact_name'] as String).toList();
          });
          await updateContactIndices();
          _originalContactOrder = [];
        }
        
        print('Auto queue ${enabled ? 'enabled' : 'disabled'} for list: ${widget.listName}');
      }
    } catch (e) {
      print('Error toggling auto queue: $e');
    }
  }

  Future<void> _applyPriorityOrdering() async {
    try {
      // Create calculator instance and build priority queue
      ContactPriorityCalculator calculator = ContactPriorityCalculator(userId);
      ContactPriorityQueue priorityQueue = await calculator.buildPriorityQueue(
        contactsData,
      );
      
      // Extract contacts in priority order (most urgent first)
      List<Map<String, dynamic>> orderedContacts = [];
      while (!priorityQueue.isEmpty) {
        PrioritizedContact? prioritizedContact = priorityQueue.extractMin();
        if (prioritizedContact != null) {
          orderedContacts.add(prioritizedContact.contactData);
        }
      }
      
      // Update UI with priority-ordered contacts
      setState(() {
        contactsData = orderedContacts;
        // Update myTiles to match contactsData order
        myTiles = orderedContacts.map((c) => c['contact_name'] as String).toList();
      });
      
      // Update Firestore indices to reflect new order
      await updateContactIndices();
      
      print('Applied priority ordering to ${orderedContacts.length} contacts');
    } catch (e) {
      print('Error applying priority ordering: $e');
    }
  }

  Future<void> updateListDescription(String description) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot snapshot = await firestore
          .collection('lists_collection')
          .where('list_name', isEqualTo: widget.listName)
          .where('user_id', isEqualTo: userId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({
          'description': description,
        });
        setState(() {
          _listDescription = description;
        });
      }
    } catch (e) {
      print('Error updating description: $e');
    }
  }
  
  // Fetch full contact data including phone numbers (using new Contact Directories structure)
  Future<void> fetchContactsData() async {
    // Use the new normalized Contact Directories
    final contacts = await fetchContactsForList(widget.listName);
    
    if (mounted) {
      setState(() {
        contactsData = contacts;
      });
    }
    print('📇 Loaded ${contacts.length} contacts from Contact Directories');
  }
  
  // Method to call the current contact
  Future<void> callCurrentContact() async {
    if (currentCallIndex >= 0 && currentCallIndex < contactsData.length) {
      String phoneNumber = contactsData[currentCallIndex]['contact_phone_number'];
      String contactName = contactsData[currentCallIndex]['contact_name'];
      String contactDocId = contactsData[currentCallIndex]['doc_id'] ?? '';
      
      // Save progress to Firestore for cross-device sync
      saveProgressToFirestore(currentCallIndex);

      // --- CYCLE TRACKING: Start cycle if not started ---
      if (_activeCycleId == null) {
        _activeCycleId = await CallCycleService.startCycle(
          listName: widget.listName,
          totalContacts: contactsData.length,
        );
        print('🚀 Started call cycle: $_activeCycleId');
      }

      // --- CYCLE TRACKING: Record dialog shown (intent created) ---
      final dialogShownAt = DateTime.now();
      _currentEventId = await CallCycleService.recordCallDialogShown(
        cycleId: _activeCycleId!,
        listName: widget.listName,
        contactDocId: contactDocId,
        contactName: contactName,
        contactPhoneNumber: phoneNumber,
        contactIndex: currentCallIndex,
        dialogShownAt: dialogShownAt,
      );
      print('📝 Recorded call intent: $_currentEventId');
      
      // Start timer and record call start time
      callStartTime = DateTime.now();
      callDuration = Duration.zero;
      callTimer?.cancel();
      callTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            callDuration = DateTime.now().difference(callStartTime!);
          });
        }
      });
      
      // Record the call timestamp in Firebase
      recordCallTimestamp(contactName, phoneNumber, widget.listName);

      // --- CYCLE TRACKING: Record dial pressed ---
      if (_activeCycleId != null && _currentEventId != null) {
        await CallCycleService.recordDialPressed(
          cycleId: _activeCycleId!,
          eventId: _currentEventId!,
          contactIndex: currentCallIndex,
          dialPressedAt: DateTime.now(),
        );
        print('📞 Recorded dial pressed for event: $_currentEventId');
      }
      
      // Make the phone call
      makePhoneCall(phoneNumber);
    }
  }

  /// Fetch previous notes for a contact and generate NLP summary
  /// 
  /// Uses multiple NLP techniques:
  /// - Tokenization: Split text into words
  /// - Stop word removal: Filter common words
  /// - Stemming: Reduce to root forms
  /// - TF-IDF: Calculate word importance
  /// - N-grams: Find common phrases
  /// 
  /// Returns: Map with keywords, phrases, and summary text
  Future<Map<String, dynamic>> _generateNoteSummary(
    String contactName,
    String phoneNumber,
  ) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      // Fetch all previous notes for this contact
      QuerySnapshot snapshot = await firestore
          .collection('contact_notes')
          .where('user_id', isEqualTo: userId)
          .where('contact_name', isEqualTo: contactName)
          .where('contact_phone_number', isEqualTo: phoneNumber)
          .orderBy('timestamp', descending: true)
          .get();
      
      // Extract note texts (exclude the current "Call initiated" note if it exists)
      List<String> noteTexts = [];
      for (var doc in snapshot.docs) {
        String noteText = doc.data() is Map<String, dynamic> 
            ? (doc.data() as Map<String, dynamic>)['note_text'] ?? ''
            : '';
        
        // Only include notes with actual content (not just "Call initiated")
        if (noteText.isNotEmpty && noteText.trim().toLowerCase() != 'call initiated') {
          noteTexts.add(noteText);
        }
      }
      
      print('📝 Fetched ${noteTexts.length} previous notes for NLP analysis');
      
      // Generate summary using NLP techniques
      Map<String, dynamic> summary = NLPService.generateNoteSummary(noteTexts);
      
      print('🤖 NLP Summary generated:');
      print('   Keywords: ${summary['keywords']}');
      print('   Phrases: ${summary['common_phrases']}');
      print('   Summary: ${summary['summary_text']}');
      
      return summary;
    } catch (e) {
      print('❌ Error generating note summary: $e');
      return {
        'keywords': [],
        'common_phrases': [],
        'total_notes': 0,
        'total_words': 0,
        'summary_text': 'No previous notes available.',
      };
    }
  }

  Future<void> showFeedbackDialog(String contactName, String phoneNumber) async {
    // Only show if enabled
    if (!showFeedbackDialogEnabled) return;
    
    // Generate NLP summary of previous notes
    Map<String, dynamic> noteSummary = await _generateNoteSummary(
      contactName,
      phoneNumber,
    );
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => CallFeedbackDialog(
        contactName: contactName,
        phoneNumber: phoneNumber,
        listName: widget.listName,
        callDuration: callDuration,
        noteSummary: noteSummary, // Pass NLP summary to dialog
        onFeedbackSubmitted: (rating, notes) async {
          await updateCallFeedback(
            contactName,
            phoneNumber,
            widget.listName,
            rating,
            notes,
            callDuration.inSeconds
          );
        },
      ),
    );
  }
  
  // Method to move to the next contact
  Future<void> moveToNextContact() async {
    // If we haven't started calling yet, start with the first contact
    if (currentCallIndex < 0 || currentCallIndex >= contactsData.length) {
      setState(() {
        currentCallIndex = 0;
      });
      callCurrentContact();
      return;
    }

    // Capture the current contact details for feedback
    final String contactName = contactsData[currentCallIndex]['contact_name'];
    final String phoneNumber = contactsData[currentCallIndex]['contact_phone_number'];

    // Stop the in-call timer
    callTimer?.cancel();

    // Show feedback dialog for the CURRENT contact (only once per contact)
    if (showFeedbackDialogEnabled) {
      // Generate NLP summary of previous notes
      Map<String, dynamic> noteSummary = await _generateNoteSummary(
        contactName,
        phoneNumber,
      );
      
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => CallFeedbackDialog(
            contactName: contactName,
            phoneNumber: phoneNumber,
            listName: widget.listName,
            callDuration: callDuration,
            noteSummary: noteSummary, // Pass NLP summary to dialog
            onFeedbackSubmitted: (rating, notes) async {
              await updateCallFeedback(
                contactName,
                phoneNumber,
                widget.listName,
                rating,
                notes,
                callDuration.inSeconds,
              );
            },
          ),
        );
      }
    }

    // Advance to the next contact and place the next call AFTER the feedback dialog is closed
    if (mounted) {
      setState(() {
        currentCallIndex++;
        if (currentCallIndex >= contactsData.length) {
          currentCallIndex = 0; // Loop back to the first contact
        }
      });
      // Save progress to Firestore for cross-device sync
      await saveProgressToFirestore(currentCallIndex);
    }
    // Start the next call regardless of whether feedback was submitted or dialog dismissed
    callCurrentContact();
  }

  Future<List<String>> fetchContactsAsArray(String selectedList) async {
    // Use the new Contact Directories structure
    return await fetchContactNamesForList(selectedList);
  }

  Future<void> updateContactIndices() async {
    // Use the new Contact Directories structure
    await updateContactIndicesForList(widget.listName, myTiles);
  }

  void updateMyTiles(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final String tile = myTiles.removeAt(oldIndex);
      myTiles.insert(newIndex, tile);
    });
    updateContactIndices();
  }
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color.fromRGBO(248, 248, 250, 1),
    body: SafeArea(
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
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
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      color: const Color.fromRGBO(64, 105, 225, 1),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.listName,
                            style: AppleTypography.withAppleFont(
                              AppleTypography.headline4.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color.fromRGBO(64, 105, 225, 1),
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${myTiles.length} contacts • Drag to reorder',
                            style: AppleTypography.withAppleFont(
                              AppleTypography.body2.copyWith(color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Settings Toggle Button
          InkWell(
            onTap: () {
              setState(() {
                isSettingsExpanded = !isSettingsExpanded;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(64, 105, 225, 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.settings,
                          color: const Color.fromRGBO(64, 105, 225, 1),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'List Settings',
                        style: AppleTypography.withAppleFont(
                          AppleTypography.subtitle1.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  AnimatedRotation(
                    turns: isSettingsExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Collapsible Settings Section
        AnimatedSize(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: isSettingsExpanded
              ? Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: TextField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            hintText: 'Enter list description',
                            border: OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.save),
                              onPressed: () {
                                updateListDescription(_descriptionController.text);
                              },
                            ),
                          ),
                          maxLines: 2,
                        ),
                      ),
                      // Feedback Dialog Toggle with Liquid Glass Effect
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.7),
                                Colors.white.withOpacity(0.3),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Show feedback dialog',
                                      style: AppleTypography.withAppleFont(
                                        AppleTypography.subtitle1.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Ask for feedback after each call',
                                      style: AppleTypography.withAppleFont(
                                        AppleTypography.body2.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              CNSwitch(
                                value: showFeedbackDialogEnabled,
                                onChanged: (value) async {
                                  await toggleFeedbackDialog(value);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Auto Queue toggle with Liquid Glass Effect (Priority Queue / Min-Heap)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.7),
                                Colors.white.withOpacity(0.3),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Auto Queue',
                                      style: AppleTypography.withAppleFont(
                                        AppleTypography.subtitle1.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Automatically reorder contacts in queue based on priority: ${ContactPriorityCalculator.getPriorityFactorsDescription()}',
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
                              CNSwitch(
                                value: autoQueueEnabled,
                                onChanged: (value) async {
                                  await toggleAutoQueue(value);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Auto-cycle toggle with Liquid Glass Effect
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.7),
                                Colors.white.withOpacity(0.3),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Auto-cycle to next contact',
                                      style: AppleTypography.withAppleFont(
                                        AppleTypography.subtitle1.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Automatically dial next contact when you return',
                                      style: AppleTypography.withAppleFont(
                                        AppleTypography.body2.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              CNSwitch(
                                value: autoCycleEnabled,
                                onChanged: (value) async {
                                  await toggleAutoCycle(value);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Manual Refresh Stats Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.7),
                                Colors.white.withOpacity(0.3),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Refresh Call Stats',
                                      style: AppleTypography.withAppleFont(
                                        AppleTypography.subtitle1.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Sync with Mac call history',
                                      style: AppleTypography.withAppleFont(
                                        AppleTypography.body2.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _isReconciling
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : IconButton(
                                      icon: Icon(Icons.refresh, color: Color.fromRGBO(64, 105, 225, 1)),
                                      onPressed: _runReconciliation,
                                    ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                    ],
                  ),
                )
              : SizedBox.shrink(),
        ),
        // Call Cycle Status Bar (only shown when cycle is active)
        if (autoCycleEnabled && currentCallIndex >= 0)
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isPaused
                    ? [
                        Colors.orange.shade400,
                        Colors.orange.shade600,
                      ]
                    : [
                        Colors.blue.shade400,
                        Colors.blue.shade600,
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (isPaused ? Colors.orange : Colors.blue).withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isPaused ? Icons.pause_circle_filled : Icons.autorenew,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPaused ? 'Call Cycle Paused' : 'Auto-Calling Active',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Contact ${currentCallIndex + 1} of ${contactsData.length}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                // Progress bar
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${((currentCallIndex + 1) / contactsData.length * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: contactsData.isEmpty ? 0 : (currentCallIndex + 1) / contactsData.length,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isPaused ? Colors.amber.shade300 : Colors.lightGreen.shade300,
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          setState(() {
                            isPaused = !isPaused;
                          });
                          if (isPaused) {
                            _autoCycleTimer?.cancel();
                            print('⏸️ Call cycle paused');
                          } else {
                            print('▶️ Call cycle resumed');
                          }
                          // Save pause state to Firestore
                          await saveProgressToFirestore(currentCallIndex);
                        },
                        icon: Icon(
                          isPaused ? Icons.play_arrow : Icons.pause,
                          size: 20,
                        ),
                        label: Text(
                          isPaused ? 'Resume' : 'Pause',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade500,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await _endCycleAndReconcile();
                        },
                        icon: Icon(
                          Icons.stop_circle,
                          size: 20,
                        ),
                        label: Text(
                          'End Loop',
                          style: AppleTypography.withAppleFont(
                            AppleTypography.body1.copyWith(
                              fontWeight: FontWeight.w600,
                            )
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade500,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            color: Color.fromRGBO(64, 105, 225, 1),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading contacts...',
                            style: AppleTypography.withAppleFont(
                              AppleTypography.body1.copyWith(color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                    )
                  : currentCallIndex < 0
                      ? ReorderableListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 280),
                          children: [
                            for (int i = 0; i < myTiles.length; i++)
                              Container(
                                key: ValueKey(myTiles[i]),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      if (i < contactsData.length) {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => ContactNotesView(
                                              contactName: contactsData[i]['contact_name'],
                                              contactPhoneNumber: contactsData[i]['contact_phone_number'],
                                              listName: widget.listName,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          // Drag handle
                                          ReorderableDragStartListener(
                                            index: i,
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(Icons.drag_handle, color: Colors.grey.shade600, size: 20),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Contact info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  myTiles[i],
                                                  style: AppleTypography.withAppleFont(
                                                    AppleTypography.subtitle1.copyWith(
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.grey.shade800,
                                                    ),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if (i < contactsData.length) ...[
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.phone_outlined,
                                                        size: 14,
                                                        color: Colors.grey.shade500,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          contactsData[i]['contact_phone_number'] ?? '',
                                                          style: AppleTypography.withAppleFont(
                                                            AppleTypography.body2.copyWith(
                                                              color: Colors.grey.shade600,
                                                            ),
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          // Action buttons
                                          Container(
                                            decoration: BoxDecoration(
                                              color: const Color.fromRGBO(64, 105, 225, 0.1),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: IconButton(
                                              icon: const Icon(Icons.note_add),
                                              color: const Color.fromRGBO(64, 105, 225, 1),
                                              iconSize: 22,
                                              onPressed: () {
                                                if (i < contactsData.length) {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (context) => ContactNotesView(
                                                        contactName: contactsData[i]['contact_name'],
                                                        contactPhoneNumber: contactsData[i]['contact_phone_number'],
                                                        listName: widget.listName,
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                              tooltip: 'Add note',
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: IconButton(
                                              icon: const Icon(Icons.delete_outline),
                                              color: Colors.red.shade400,
                                              iconSize: 22,
                                              onPressed: () {
                                                deleteSpecificContact(myTiles[i]);
                                              },
                                              tooltip: 'Delete contact',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                          onReorder: (oldIndex, newIndex) {
                            updateMyTiles(oldIndex, newIndex);
                          },
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                          children: [
                            for (int i = 0; i < myTiles.length; i++)
                              Container(
                                key: ValueKey(myTiles[i]),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: i == currentCallIndex 
                                      ? Border.all(color: const Color.fromRGBO(64, 105, 225, 1), width: 3.0)
                                      : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: i == currentCallIndex 
                                          ? const Color.fromRGBO(64, 105, 225, 0.2)
                                          : Colors.black.withOpacity(0.04),
                                      blurRadius: i == currentCallIndex ? 12 : 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      if (i < contactsData.length) {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => ContactNotesView(
                                              contactName: contactsData[i]['contact_name'],
                                              contactPhoneNumber: contactsData[i]['contact_phone_number'],
                                              listName: widget.listName,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          // Current call indicator
                                          if (i == currentCallIndex)
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: const Color.fromRGBO(64, 105, 225, 0.15),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(Icons.call, color: Color.fromRGBO(64, 105, 225, 1), size: 20),
                                            )
                                          else
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '${i + 1}',
                                                style: AppleTypography.withAppleFont(
                                                  AppleTypography.body2.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          const SizedBox(width: 12),
                                          // Contact info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  myTiles[i],
                                                  style: AppleTypography.withAppleFont(
                                                    AppleTypography.subtitle1.copyWith(
                                                      fontWeight: FontWeight.w600,
                                                      color: i == currentCallIndex 
                                                          ? const Color.fromRGBO(64, 105, 225, 1)
                                                          : Colors.grey.shade800,
                                                    ),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if (i < contactsData.length) ...[
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.phone_outlined,
                                                        size: 14,
                                                        color: Colors.grey.shade500,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          contactsData[i]['contact_phone_number'] ?? '',
                                                          style: AppleTypography.withAppleFont(
                                                            AppleTypography.body2.copyWith(
                                                              color: Colors.grey.shade600,
                                                            ),
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          // Note button only during call cycle
                                          Container(
                                            decoration: BoxDecoration(
                                              color: const Color.fromRGBO(64, 105, 225, 0.1),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: IconButton(
                                              icon: const Icon(Icons.note_add),
                                              color: const Color.fromRGBO(64, 105, 225, 1),
                                              iconSize: 22,
                                              onPressed: () {
                                                if (i < contactsData.length) {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (context) => ContactNotesView(
                                                        contactName: contactsData[i]['contact_name'],
                                                        contactPhoneNumber: contactsData[i]['contact_phone_number'],
                                                        listName: widget.listName,
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                              tooltip: 'Add note',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
              // Only show add and call buttons when call cycle is not active
              if (currentCallIndex < 0) ...[
                Positioned(
                  key: const ValueKey('add_contact_button'),
                  bottom: 200,
                  right: 30,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.orange.shade500,
                          Colors.orange.shade600,
                        ],
                      ),
                    ),
                    child: CNButton.icon(
                      icon: const CNSymbol('plus', size: 22),
                      style: CNButtonStyle.prominentGlass,
                      onPressed: () async {
                        // Show options: single or multiple contact upload
                        final choice = await showModalBottomSheet<String>(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (BuildContext context) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                              ),
                              padding: EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  Text(
                                    'Add Contacts',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  ListTile(
                                    leading: Container(
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(Icons.person_add, color: Colors.blue.shade700),
                                    ),
                                    title: Text('Add Single Contact'),
                                    subtitle: Text('Pick one contact from your phone'),
                                    onTap: () => Navigator.pop(context, 'single'),
                                  ),
                                  SizedBox(height: 8),
                                  ListTile(
                                    leading: Container(
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(Icons.people, color: Colors.orange.shade700),
                                    ),
                                    title: Text('Add Multiple Contacts'),
                                    subtitle: Text('Select multiple contacts at once'),
                                    onTap: () => Navigator.pop(context, 'multiple'),
                                  ),
                                  SizedBox(height: 20),
                                ],
                              ),
                            );
                          },
                        );

                        if (choice == 'single') {
                          await upload_button_on_dialer_contacts_view(context, widget.listName);
                        } else if (choice == 'multiple') {
                          int addedCount = await uploadMultipleContacts(context, widget.listName);
                          if (addedCount > 0 && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added $addedCount contact${addedCount == 1 ? '' : 's'} to ${widget.listName}'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                        
                        // Refresh the contact list
                        fetchContactsAsArray(widget.listName).then((contacts) {
                          setState(() {
                            myTiles = contacts;
                            isLoading = false;
                          });
                          updateContactIndices();
                          fetchContactsData();
                        });
                      },
                    ),
                  ),
                ),
                Positioned(
                  key: const ValueKey('start_call_button'),
                  bottom: 130,
                  right: 30,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.green.shade500,
                          Colors.green.shade600,
                        ],
                      ),
                    ),
                    child: CNButton.icon(
                      icon: const CNSymbol('phone.fill', size: 22),
                      style: CNButtonStyle.prominentGlass,
                      onPressed: () {
                        setState(() {
                          currentCallIndex = 0;
                        });
                        callCurrentContact();
                      },
                    ),
                  ),
                ),
              ],
              // Always show next button when contacts exist
              if (contactsData.isNotEmpty)
                Positioned(
                  key: const ValueKey('next_contact_button'),
                  bottom: 60,
                  right: 30,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF6BB6FF),
                          const Color(0xFF5AA8EE),
                        ],
                      ),
                    ),
                    child: CNButton.icon(
                      icon: const CNSymbol('arrow.right', size: 22),
                      style: CNButtonStyle.prominentGlass,
                      onPressed: () {
                        moveToNextContact();
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  ),
);
}





  Future<void> updateCallFeedback(
    String contactName,
    String phoneNumber,
    String listName,
    int rating,
    String notes,
    int durationSeconds
  ) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      CollectionReference notesRef = firestore.collection('contact_notes');
      
      print('Updating call feedback for: $contactName, $phoneNumber, Rating: $rating');
      
      // Find the most recent call record for this contact (must include user_id)
      QuerySnapshot snapshot = await notesRef
          .where('user_id', isEqualTo: userId)
          .where('contact_name', isEqualTo: contactName)
          .where('contact_phone_number', isEqualTo: phoneNumber)
          .where('list_name', isEqualTo: listName)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      print('Found ${snapshot.docs.length} matching call records');

      if (snapshot.docs.isNotEmpty) {
        // Update existing call record
        DocumentReference docRef = snapshot.docs.first.reference;
        String docId = snapshot.docs.first.id;
        
        print('Updating document ID: $docId with rating: $rating');
        
        await docRef.update({
          'rating': rating,
          'duration_seconds': durationSeconds,
          'has_feedback': true,
          'note_text': notes,
        });

        print('✅ Call feedback updated successfully! Doc ID: $docId, Rating: $rating/5');
      } else {
        // Create new call record with all feedback data
        Timestamp timestamp = Timestamp.now();
        
        print('No existing call record found, creating new one with rating: $rating');
        
        Map<String, dynamic> callFeedbackData = {
          'user_id': userId,
          'contact_name': contactName,
          'contact_phone_number': phoneNumber,
          'list_name': listName,
          'timestamp': timestamp,
          'rating': rating,
          'duration_seconds': durationSeconds,
          'has_feedback': true,
          'note_text': notes,
        };

        DocumentReference newDoc = await notesRef.add(callFeedbackData);
        print('✅ New call feedback record created! Doc ID: ${newDoc.id}, Rating: $rating/5');
      }
    } catch (e) {
      print('❌ Error updating call feedback: $e');
      print('Error details: ${e.toString()}');
    }
  }

  /// End the active call cycle, compute completion, and run reconciliation.
  Future<void> _endCycleAndReconcile() async {
    final completedContacts = currentCallIndex >= 0 ? currentCallIndex + 1 : 0;
    final totalContacts = contactsData.length;

    // Clean up local state
    setState(() {
      currentCallIndex = -1;
      isPaused = false;
    });
    _autoCycleTimer?.cancel();
    callTimer?.cancel();
    await clearSavedProgress();

    // End cycle in Firestore
    if (_activeCycleId != null) {
      await CallCycleService.endCycle(
        cycleId: _activeCycleId!,
        completedContacts: completedContacts,
        totalContacts: totalContacts,
      );
      print('🛑 Call cycle ended: $_activeCycleId ($completedContacts/$totalContacts)');

      // Auto-run reconciliation
      await _runReconciliation();
    }

    // Clear cycle tracking
    _activeCycleId = null;
    _currentEventId = null;
  }

  /// Manually trigger reconciliation for the most recent cycle (or active one).
  Future<void> _runReconciliation() async {
    if (_isReconciling) return;
    setState(() => _isReconciling = true);

    try {
      String? cycleIdToReconcile = _activeCycleId;

      // If no active cycle, find the most recent ended cycle for this list
      if (cycleIdToReconcile == null) {
        final snap = await FirebaseFirestore.instance
            .collection(CallCycleService.listCyclesCollection)
            .where('user_id', isEqualTo: userId)
            .where('list_name', isEqualTo: widget.listName)
            .orderBy('started_at_server', descending: true)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          cycleIdToReconcile = snap.docs.first.id;
        }
      }

      if (cycleIdToReconcile != null) {
        await CallCycleService.reconcileCycle(cycleId: cycleIdToReconcile);
        print('🔄 Reconciliation complete for cycle: $cycleIdToReconcile');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stats refreshed from call history')),
          );
        }
      }
    } catch (e) {
      print('❌ Reconciliation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh stats: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isReconciling = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _descriptionController.dispose();
    callTimer?.cancel();
    _autoCycleTimer?.cancel();
    super.dispose();
  }

  void deleteSpecificContact(String contactName) async {
    try {
      // Find the contact's phone number from the loaded contacts data
      final contact = contactsData.firstWhere(
        (c) => c['contact_name'] == contactName,
        orElse: () => {},
      );
      
      if (contact.isNotEmpty) {
        final phoneNumber = contact['contact_phone_number'] as String?;
        
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          // Use the new Contact Directories structure to remove from list
          await removeContactFromList(
            contactPhoneNumber: phoneNumber,
            listName: widget.listName,
          );
        }

        setState(() {
          myTiles.remove(contactName);
          contactsData.removeWhere((c) => c['contact_name'] == contactName);
        });

        print('$contactName removed from ${widget.listName}');
      }
    } catch (e) {
      print('Error deleting contact: $e');
    }
  }
}