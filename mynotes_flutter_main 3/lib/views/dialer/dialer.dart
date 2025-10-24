import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/views/list/firebase_services.dart';
import 'package:flutter_application_1/views/notes/contact_notes_view.dart';
import 'package:flutter_application_1/utilities/dialogs/call_feedback_dialog.dart';


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

class _DialerContactsViewState extends State<DialerContactsView> {
  List<String> myTiles = [];
  bool isLoading = true;
  int currentCallIndex = -1; // Track the currently called contact
  List<Map<String, dynamic>> contactsData = []; // Store full contact data
  DateTime? callStartTime;
  Duration callDuration = Duration.zero;
  Timer? callTimer;
  late TextEditingController _descriptionController;
  String? _listDescription;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    fetchListDescription();
    fetchContactsAsArray(widget.listName).then((contacts) {
      setState(() {
        myTiles = contacts;
        isLoading = false;
      });
      updateContactIndices();
      fetchContactsData();
    });
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
    
    setState(() {
      contactsData = data;
    });
  }
  
  // Method to call the current contact
  void callCurrentContact() {
    if (currentCallIndex >= 0 && currentCallIndex < contactsData.length) {
      String phoneNumber = contactsData[currentCallIndex]['contact_phone_number'];
      String contactName = contactsData[currentCallIndex]['contact_name'];
      
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

      // Show feedback dialog immediately for first contact
      if (currentCallIndex == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showFeedbackDialog(contactName, phoneNumber);
        });
      }
    }
  }

  void showFeedbackDialog(String contactName, String phoneNumber) {
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
  void moveToNextContact() {
    if (currentCallIndex >= 0 && currentCallIndex < contactsData.length) {
      String contactName = contactsData[currentCallIndex]['contact_name'];
      String phoneNumber = contactsData[currentCallIndex]['contact_phone_number'];
      
      // Stop timer
      callTimer?.cancel();
      
      // Show feedback dialog
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => CallFeedbackDialog(
          contactName: contactName,
          phoneNumber: phoneNumber,
          listName: widget.listName,
          callDuration: callDuration,
          onFeedbackSubmitted: (answered, voicemail, rating) async {
            // Update Firebase with call feedback
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
    
    setState(() {
      currentCallIndex++;
      if (currentCallIndex >= contactsData.length) {
        currentCallIndex = 0; // Loop back to the first contact
      }
    });
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
    appBar: AppBar(title: Text("Contacts in ${widget.listName}")),
    body: Column(
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
            Navigator.pop(context, true);
          },
              ),
            ),
            maxLines: 2,
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ReorderableListView(
                      padding: const EdgeInsets.all(10),
                      children: [
                        for (int i = 0; i < myTiles.length; i++)
                          Padding(
                            key: ValueKey(myTiles[i]),
                            padding: const EdgeInsets.all(8.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                border: i == currentCallIndex 
                                    ? Border.all(color: Colors.blue, width: 3.0)
                                    : null,
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: ListTile(
                                title: Text(myTiles[i]),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.note_add),
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
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete),
                                      onPressed: () {
                                        deleteSpecificContact(myTiles[i]);
                                      },
                                    ),
                                  ],
                                ),
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
                              ),
                            ),
                          ),
                      ],
                      onReorder: (oldIndex, newIndex) {
                        updateMyTiles(oldIndex, newIndex);
                      },
                    ),
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
                  child: Icon(Icons.add),
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
                  child: Icon(Icons.call),
                  tooltip: 'Call Contact',
                ),
              ),
              Positioned(
                bottom: 60,
                right: 30,
                child: FloatingActionButton(
                  onPressed: () {
                    moveToNextContact();
                  },
                  child: Icon(Icons.arrow_forward),
                  tooltip: 'Next Contact',
                ),
              ),
            ],
          ),
        ),
      ],
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
    _descriptionController.dispose();
    callTimer?.cancel();
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
      DocumentReference docRef = snapshot.docs.first.reference;
      await docRef.delete();

      setState(() {
        myTiles.remove(contactName);
      });

      print('$contactName deleted');
    }
  } catch (e) {
    print('Error deleting contact: $e');
  }
}









}
