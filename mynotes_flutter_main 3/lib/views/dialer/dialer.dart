import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/views/list/firebase_services.dart';


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

  @override
  void initState() {
    super.initState();
    fetchContactsAsArray(widget.listName).then((contacts) {
      setState(() {
        myTiles = contacts;
        isLoading = false;
      });
      updateContactIndices();
    });
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
                  for (final tile in myTiles)
                    Padding(
                      key: ValueKey(tile),
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        color: Colors.grey[200],
                        child: ListTile(
                          title: Text(tile),
                          trailing: IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () {
                              // Handle delete action
                              deleteSpecificContact(tile);
                              
                            },
                          ),
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
              // Fetch and show document details
              fetchDocumentAtIndexAndShowDialog(context, index, widget.listName);
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
              // Reset or handle action
              index = 0;
            },
            child: Icon(Icons.replay_outlined),
            tooltip: 'Reset',
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

