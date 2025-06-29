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








class _list_view_visibleState extends State<list_view_visible> with SingleTickerProviderStateMixin {
  List<String> myTiles = [];
  bool isLoading = true;
  late AnimationController _animationController;
  Map<String, TextEditingController> descriptionControllers = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    Firebase.initializeApp();
    
    fetchTilesAsArray(userId).then((contacts) async {
      // Load descriptions for each list
      for (String listName in contacts) {
        String? description = await getListDescription(listName);
        descriptionControllers[listName] = TextEditingController(text: description ?? '');
      }
      
      setState(() {
        myTiles = contacts;
        isLoading = false;
      });
    });
  }

  Future<String?> getListDescription(String listName) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot snapshot = await firestore
          .collection('lists_collection')
          .where('list_name', isEqualTo: listName)
          .where('user_id', isEqualTo: userId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first['description'] as String?;
      }
    } catch (e) {
      print('Error getting description: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> updateListDescription(String listName, String description) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot snapshot = await firestore
          .collection('lists_collection')
          .where('list_name', isEqualTo: listName)
          .where('user_id', isEqualTo: userId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({
          'description': description,
        });
      }
    } catch (e) {
      print('Error updating description: $e');
    }
  }

  Future<Map<String, dynamic>> _getListStats(String listName) async {
    try {
      // Get contact count
      final contactsSnapshot = await FirebaseFirestore.instance
          .collection('lists')
          .where('list_name', isEqualTo: listName)
          .where('user_id', isEqualTo: userId)
          .get();

      // Get last dialed time from contact_notes collection
      final lastDialedQuery = await FirebaseFirestore.instance
          .collection('contact_notes')
          .where('list_name', isEqualTo: listName)
          .where('user_id', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      DateTime? lastDialed;
      if (lastDialedQuery.docs.isNotEmpty) {
        lastDialed = (lastDialedQuery.docs.first['timestamp'] as Timestamp).toDate();
      }

      return {
        'count': contactsSnapshot.size,
        'lastDialed': lastDialed != null 
            ? '${lastDialed.day}/${lastDialed.month}/${lastDialed.year} ${lastDialed.hour.toString().padLeft(2, '0')}:${lastDialed.minute.toString().padLeft(2, '0')}'
            : 'Never',
      };
    } catch (e) {
      print('Error getting list stats: $e');
      return {'count': 0, 'lastDialed': 'Never'};
    }
  }



@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: Text("Lists ")),
    body: GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Stack(
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
                  child: ExpansionTile(
                    title: Text(tile),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.people),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => DialerContactsView(listName: tile),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.info_outline),
                          onPressed: null,
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            TextField(
                              controller: descriptionControllers[tile],
                              decoration: InputDecoration(
                                hintText: 'Enter list description',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                              onChanged: (value) {
                                updateListDescription(tile, value); 
                              },
                            ),
                            SizedBox(height: 16),
                            FutureBuilder(
                              future: _getListStats(tile),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  final stats = snapshot.data as Map<String, dynamic>;
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Contacts: ${stats['count']}'),
                                      Text('Last dialed: ${stats['lastDialed'] ?? 'Never'}'),
                                    ],
                                  );
                                }
                                return CircularProgressIndicator();
                              },
                            ),
                            SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                deleteSpecificContact(tile);
                              },
                              child: Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onExpansionChanged: (expanded) {
                      if (expanded) {
                        _animationController.forward();
                        // Dismiss keyboard when expanding
                        FocusScope.of(context).unfocus();
                      } else {
                        _animationController.reverse();
                      }
                    },
                    initiallyExpanded: false,
                    tilePadding: EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: EdgeInsets.only(bottom: 16),
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
