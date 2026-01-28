import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
  bool _isInCall = false; // Track if user is currently in a call
  Timer? _autoCycleTimer; // Timer for delayed auto-cycle after app resume
  bool isPaused = false; // Track if auto-cycle is paused
  bool isSettingsExpanded = false; // Track if settings section is expanded

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _descriptionController = TextEditingController();
    fetchListDescription();
    loadFeedbackDialogSetting();
    loadAutoCycleSetting();
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
    } else if (state == AppLifecycleState.resumed && _isInCall && autoCycleEnabled && !isPaused) {
      // User returned to the app after being in a call
      print('📱 App resumed - auto-cycling to next contact in 2 seconds...');
      _isInCall = false;
      
      // Wait 2 seconds before auto-cycling to give user time to see what's happening
      _autoCycleTimer?.cancel();
      _autoCycleTimer = Timer(Duration(seconds: 2), () {
        if (mounted && autoCycleEnabled && !isPaused) {
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
  
  // Fetch full contact data including phone numbers
  Future<void> fetchContactsData() async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    QuerySnapshot snapshot = await firestore
        .collection('lists')
        .where('list_name', isEqualTo: widget.listName)
        .where('user_id', isEqualTo: userId)
        .orderBy("contact_index")
        .get();
        
    List<Map<String, dynamic>> data = snapshot.docs.map((doc) {
      return doc.data() as Map<String, dynamic>;
    }).toList();
    
    if (mounted) {
      setState(() {
        contactsData = data;
      });
    }
    print('📇 Loaded ${data.length} contacts');
  }
  
  // Method to call the current contact
  void callCurrentContact() {
    if (currentCallIndex >= 0 && currentCallIndex < contactsData.length) {
      String phoneNumber = contactsData[currentCallIndex]['contact_phone_number'];
      String contactName = contactsData[currentCallIndex]['contact_name'];
      
      // Save progress to Firestore for cross-device sync
      saveProgressToFirestore(currentCallIndex);
      
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
      
      // Make the phone call
      makePhoneCall(phoneNumber);
    }
  }

  void showFeedbackDialog(String contactName, String phoneNumber) {
    // Only show if enabled
    if (!showFeedbackDialogEnabled) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => CallFeedbackDialog(
        contactName: contactName,
        phoneNumber: phoneNumber,
        listName: widget.listName,
        callDuration: callDuration,
        onFeedbackSubmitted: (answered, voicemail, rating) async {
          await updateCallFeedback(
            contactName,
            phoneNumber,
            widget.listName,
            answered,
            voicemail,
            rating,
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
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => CallFeedbackDialog(
          contactName: contactName,
          phoneNumber: phoneNumber,
          listName: widget.listName,
          callDuration: callDuration,
          onFeedbackSubmitted: (answered, voicemail, rating) async {
            await updateCallFeedback(
              contactName,
              phoneNumber,
              widget.listName,
              answered,
              voicemail,
              rating,
              callDuration.inSeconds,
            );
          },
        ),
      );
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
    
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    QuerySnapshot snapshot = await firestore
        .collection('lists')
        .where('list_name', isEqualTo: selectedList)
        .orderBy("contact_index")
        .get();

    List<String> listContacts = snapshot.docs.map((doc) {
      return doc.get('contact_name') as String;
    }).toList();



  print(listContacts);
    return listContacts;
    
  }

  Future<void> updateContactIndices() async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    WriteBatch batch = firestore.batch();

    for (int i = 0; i < myTiles.length; i++) {
      String contactName = myTiles[i];
      QuerySnapshot snapshot = await firestore
          .collection('lists')
          .where('list_name', isEqualTo: widget.listName)
          .where('contact_name', isEqualTo: contactName)
          .get();

      if (snapshot.docs.isNotEmpty) {
        DocumentReference docRef = snapshot.docs.first.reference;
        batch.update(docRef, {'contact_index': i});
      }
    }

    await batch.commit();
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
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Ask for feedback after each call',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  await toggleFeedbackDialog(!showFeedbackDialogEnabled);
                                },
                                child: AnimatedContainer(
                                  duration: Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  width: 56,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: showFeedbackDialogEnabled
                                          ? [
                                              Color(0xFF4CAF50).withOpacity(0.8),
                                              Color(0xFF45A049).withOpacity(0.9),
                                            ]
                                          : [
                                              Colors.grey.withOpacity(0.4),
                                              Colors.grey.withOpacity(0.5),
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.4),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: showFeedbackDialogEnabled
                                            ? Color(0xFF4CAF50).withOpacity(0.3)
                                            : Colors.grey.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      // Glass reflection effect
                                      Positioned(
                                        top: 2,
                                        left: 2,
                                        right: 2,
                                        child: Container(
                                          height: 12,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(18),
                                            ),
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.white.withOpacity(0.4),
                                                Colors.white.withOpacity(0.0),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Toggle knob
                                      AnimatedAlign(
                                        duration: Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                        alignment: showFeedbackDialogEnabled
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: Container(
                                          margin: EdgeInsets.all(3),
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Colors.white,
                                                Colors.grey.shade100,
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.2),
                                                blurRadius: 4,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Automatically dial next contact when you return',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  await toggleAutoCycle(!autoCycleEnabled);
                                },
                                child: AnimatedContainer(
                                  duration: Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  width: 56,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: autoCycleEnabled
                                          ? [
                                              Color(0xFF2196F3).withOpacity(0.8),
                                              Color(0xFF1976D2).withOpacity(0.9),
                                            ]
                                          : [
                                              Colors.grey.withOpacity(0.4),
                                              Colors.grey.withOpacity(0.5),
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.4),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: autoCycleEnabled
                                            ? Color(0xFF2196F3).withOpacity(0.3)
                                            : Colors.grey.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      // Glass reflection effect
                                      Positioned(
                                        top: 2,
                                        left: 2,
                                        right: 2,
                                        child: Container(
                                          height: 12,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(18),
                                            ),
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.white.withOpacity(0.4),
                                                Colors.white.withOpacity(0.0),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Toggle knob
                                      AnimatedAlign(
                                        duration: Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                        alignment: autoCycleEnabled
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: Container(
                                          margin: EdgeInsets.all(3),
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Colors.white,
                                                Colors.grey.shade100,
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.2),
                                                blurRadius: 4,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
                          setState(() {
                            currentCallIndex = -1;
                            isPaused = false;
                          });
                          _autoCycleTimer?.cancel();
                          callTimer?.cancel();
                          await clearSavedProgress();
                          print('🛑 Call cycle ended');
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
                  bottom: 200,
                  right: 30,
                  child: FloatingActionButton(
                    onPressed: () async {
                      await upload_button_on_dialer_contacts_view(context, widget.listName);
                      fetchContactsAsArray(widget.listName).then((contacts) {
                        setState(() {
                          myTiles = contacts;
                          isLoading = false;
                        });
                        updateContactIndices();
                        fetchContactsData();
                      });
                    },
                    backgroundColor: const Color.fromRGBO(64, 105, 225, 1),
                    child: const Icon(Icons.add),
                    tooltip: 'Add Contact',
                  ),
                ),
                Positioned(
                  bottom: 130,
                  right: 30,
                  child: FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        currentCallIndex = 0;
                      });
                      callCurrentContact();
                    },
                    backgroundColor: Colors.green.shade500,
                    child: const Icon(Icons.call),
                    tooltip: 'Start Call Cycle',
                  ),
                ),
              ],
              // Always show next button when contacts exist
              if (contactsData.isNotEmpty)
                Positioned(
                  bottom: 60,
                  right: 30,
                  child: FloatingActionButton(
                    onPressed: () {
                      moveToNextContact();
                    },
                    backgroundColor: Colors.orange.shade500,
                    child: const Icon(Icons.arrow_forward),
                    tooltip: 'Next Contact',
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
    bool answered,
    bool voicemail,
    int rating,
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

      // Create comprehensive note text with star rating
      String noteText = '''
Call Feedback:
- Answered: ${answered ? 'Yes' : 'No'}
${!answered ? '- Voicemail Left: ${voicemail ? 'Yes' : 'No'}\n' : ''}
- Rating: ${rating > 0 ? '$rating/5 stars' : 'Not rated'}
- Duration: ${durationSeconds} seconds
''';
      
      if (voicemail) {
        noteText += 'Notes about voicemail...\n';
      }

      if (snapshot.docs.isNotEmpty) {
        // Update existing call record
        DocumentReference docRef = snapshot.docs.first.reference;
        String docId = snapshot.docs.first.id;
        
        print('Updating document ID: $docId with rating: $rating');
        
        await docRef.update({
          'answered': answered,
          'voicemail': voicemail,
          'rating': rating,
          'duration_seconds': durationSeconds,
          'has_feedback': true,
          'note_text': noteText,
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
          'answered': answered,
          'voicemail': voicemail,
          'rating': rating,
          'duration_seconds': durationSeconds,
          'has_feedback': true,
          'note_text': noteText,
        };

        DocumentReference newDoc = await notesRef.add(callFeedbackData);
        print('✅ New call feedback record created! Doc ID: ${newDoc.id}, Rating: $rating/5');
      }
    } catch (e) {
      print('❌ Error updating call feedback: $e');
      print('Error details: ${e.toString()}');
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
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    QuerySnapshot snapshot = await firestore
        .collection('lists')
        .where('list_name', isEqualTo: widget.listName)
        .where('contact_name', isEqualTo: contactName)
        .get();

    if (snapshot.docs.isNotEmpty) {
      // Get the contact's phone number before deleting
      final contactData = snapshot.docs.first.data() as Map<String, dynamic>;
      final phoneNumber = contactData['contact_phone_number'] as String?;
      
      DocumentReference docRef = snapshot.docs.first.reference;
      await docRef.delete();

      // Also update Contact Directories to remove this list from the contact
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        await _removeListFromContactDirectory(phoneNumber, widget.listName);
      }

      setState(() {
        myTiles.remove(contactName);
      });

      print('$contactName deleted');
    }
  } catch (e) {
    print('Error deleting contact: $e');
  }
}

// Remove a list from a contact in Contact Directories
Future<void> _removeListFromContactDirectory(String phoneNumber, String listName) async {
  try {
    final firestore = FirebaseFirestore.instance;
    // Normalize phone number (last 9 digits)
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final normalizedPhone = digitsOnly.length >= 9 
        ? digitsOnly.substring(digitsOnly.length - 9) 
        : digitsOnly;
    
    final docId = '${userId}_$normalizedPhone';
    final docRef = firestore.collection('Contact Directories').doc(docId);
    
    final existing = await docRef.get();
    if (existing.exists) {
      await docRef.update({
        'lists': FieldValue.arrayRemove([listName]),
        'updated_at': FieldValue.serverTimestamp(),
      });
      print('Removed list "$listName" from contact directory');
    }
  } catch (e) {
    print('Error removing list from Contact Directories: $e');
  }
}









}
