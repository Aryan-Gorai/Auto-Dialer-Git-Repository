import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/views/list/firebase_services.dart';
import 'package:flutter_application_1/views/notes/contact_notes_view.dart';


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

  @override
  void initState() {
    super.initState();
    fetchContactsAsArray(widget.listName).then((contacts) {
      setState(() {
        myTiles = contacts;
        isLoading = false;
      });
      updateContactIndices();
      fetchContactsData();
    });
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
      
      // Record the call timestamp in Firebase
      recordCallTimestamp(contactName, phoneNumber, widget.listName);
      
      // Make the phone call
      makePhoneCall(phoneNumber);
    }
  }
  
  // Method to move to the next contact
  void moveToNextContact() {
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
    body: Stack(
      children: [
        // Your main content goes here
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
                                  // Navigate to notes page for this contact
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
                                  // Handle delete action
                                  deleteSpecificContact(myTiles[i]);
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            // Navigate to notes page for this contact
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
        // FloatingActionButtons
        Positioned(
          bottom: 200, // Padding from the bottom
          right: 30, // Padding from the right
          child: FloatingActionButton(
            onPressed: () async{
              await upload_button_on_dialer_contacts_view(selectedList);

              fetchContactsAsArray(widget.listName).then((contacts) {
                setState(() {
                  myTiles = contacts;
                  isLoading = false;
                });
                // Update the indices of contacts after refreshing
                updateContactIndices();
                fetchContactsData();
              });
            },
            child: Icon(Icons.add),
            tooltip: 'Add Contact',
          ),
        ),
        Positioned(
          bottom: 130, // Padding from the bottom (stacked above the first button)
          right: 30, // Same right padding to align with the first button
          child: FloatingActionButton(
            onPressed: () {
              // Start calling the first contact
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
          bottom: 60, // Padding from the bottom (stacked above the first button)
          right: 30, // Same right padding to align with the first button
          child: FloatingActionButton(
            onPressed: () {
              // Move to next contact
              moveToNextContact();
            },
            child: Icon(Icons.arrow_forward),
            tooltip: 'Next Contact',
          ),
        ),
      ],
    ),
  );
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
