import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/views/dialer/dialer.dart';
import 'package:flutter_application_1/views/list/firebase_services.dart';


class list_view_visible extends StatefulWidget {
  const list_view_visible({super.key});

  @override
  State<list_view_visible> createState() => _list_view_visibleState();
}



    List<String> myTiles = [];
  Future<List<String>> fetchTilesAsArray(userId) async {
    
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    QuerySnapshot snapshot = await firestore
        .collection('lists_collection')
        .where('user_id', isEqualTo: userId)
        .get();

    List<String> myTiles = snapshot.docs.map((doc) {
      return doc.get('list_name') as String;
    }).toList();



  print(myTiles);
    return myTiles;
    
  }



void handleTilePress(String listName, context) {
  // Perform the action you want when a tile is pressed.
  // For example, navigate to a new screen, show details, or any other action.

  print('Tile $listName pressed');
  
  // Example: Navigate to a detail screen (assuming you have a detail screen)
  selectedList = listName;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) =>  DialerContactsView(listName: selectedList,),
    ),
  );

  // Alternatively, you could show a dialog or perform another action.
}








class _list_view_visibleState extends State<list_view_visible> {
  List<String> myTiles = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    Firebase.initializeApp();
    
    fetchTilesAsArray(userId).then((contacts) {
      setState(() {
        myTiles = contacts;
        isLoading = false;
      });
    });
  }



@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: Text("Lists ")),
    body: Stack(
  children: [
    // Your main content goes here
    isLoading  // defined at the bottom of the page
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: myTiles.length,
            itemBuilder: (context, index) {
              final tile = myTiles[index];
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  color: Colors.grey[200],
                  child: ListTile(
                    title: Text(tile),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        deleteSpecificContact(tile);

                      },

                    ),
                    onTap: () {
                        handleTilePress(tile, context);
                      },
                  ),
                ),
              );
            },
          ),
    // FloatingActionButtons
    Positioned(
      bottom: 30, // Padding from the bottom
      right: 30, // Padding from the right
      child: FloatingActionButton(
        onPressed: () async{

      // Wait for the dialog to close
      await showListDialog(context);

      // After the dialog is dismissed, continue with the next part of the code
      fetchTilesAsArray(userId).then((contacts) {
        setState(() {
          myTiles = contacts;
          isLoading = false;
        });
      });


      },
        
        child: Icon(Icons.add),
        tooltip: 'Add Contact',
      ),
    ),
  ],

),

  );
}




void deleteSpecificContact(String listName) async {
  try {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    QuerySnapshot snapshot = await firestore
        .collection('lists_collection')
        .where('list_name', isEqualTo: listName)
        .get();

    if (snapshot.docs.isNotEmpty) {
      DocumentReference docRef = snapshot.docs.first.reference;
      await docRef.delete();

      setState(() {
        myTiles.remove(listName);
      });

      print('$listName deleted');
    }
  } catch (e) {
    print('Error deleting contact: $e');
  }
}


















}

