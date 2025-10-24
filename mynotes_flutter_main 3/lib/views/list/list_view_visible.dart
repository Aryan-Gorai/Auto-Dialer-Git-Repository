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
    
    // First try to fetch with manual ordering
    QuerySnapshot snapshot = await firestore
        .collection('lists_collection')
        .where('user_id', isEqualTo: userId)
        .get();

    // Sort the results
    List<QueryDocumentSnapshot> docs = snapshot.docs.toList();
    
    // Check if any document has manual_order field
    bool hasManualOrder = docs.any((doc) => 
      (doc.data() as Map<String, dynamic>).containsKey('manual_order')
    );
    
    if (hasManualOrder) {
      // Sort by manual_order if it exists
      docs.sort((a, b) {
        int orderA = (a.data() as Map<String, dynamic>)['manual_order'] ?? 999999;
        int orderB = (b.data() as Map<String, dynamic>)['manual_order'] ?? 999999;
        return orderA.compareTo(orderB);
      });
    } else {
      // Otherwise sort by list_order (timestamp), newest first
      docs.sort((a, b) {
        Timestamp? timeA = (a.data() as Map<String, dynamic>)['list_order'] as Timestamp?;
        Timestamp? timeB = (b.data() as Map<String, dynamic>)['list_order'] as Timestamp?;
        
        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1;
        if (timeB == null) return -1;
        
        return timeB.compareTo(timeA); // Descending order (newest first)
      });
    }

    List<String> myTiles = docs.map((doc) {
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
    // Dispose all text controllers
    for (var controller in descriptionControllers.values) {
      controller.dispose();
    }
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

  // Update list order in Firestore
  Future<void> updateListOrder(String listName, int newOrder) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot snapshot = await firestore
          .collection('lists_collection')
          .where('list_name', isEqualTo: listName)
          .where('user_id', isEqualTo: userId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        // Use a numeric order field for manual reordering
        await snapshot.docs.first.reference.update({
          'manual_order': newOrder,
        });
      }
    } catch (e) {
      print('Error updating list order: $e');
    }
  }

  // Handle reordering of lists
  void onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final String item = myTiles.removeAt(oldIndex);
      myTiles.insert(newIndex, item);
    });

    // Update the order in Firebase for all affected lists
    for (int i = 0; i < myTiles.length; i++) {
      updateListOrder(myTiles[i], i);
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

  // Get the feedback dialog enabled state for a list
  Future<bool> _getFeedbackDialogEnabled(String listName) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot snapshot = await firestore
          .collection('lists_collection')
          .where('list_name', isEqualTo: listName)
          .where('user_id', isEqualTo: userId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        // Default to true if the field doesn't exist
        return snapshot.docs.first['show_feedback_dialog'] as bool? ?? true;
      }
    } catch (e) {
      print('Error getting feedback dialog setting: $e');
    }
    return true; // Default to enabled
  }

  // Toggle the feedback dialog setting for a list
  Future<void> _toggleFeedbackDialog(String listName, bool enabled) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot snapshot = await firestore
          .collection('lists_collection')
          .where('list_name', isEqualTo: listName)
          .where('user_id', isEqualTo: userId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({
          'show_feedback_dialog': enabled,
        });
        print('Feedback dialog ${enabled ? 'enabled' : 'disabled'} for list: $listName');
      }
    } catch (e) {
      print('Error toggling feedback dialog: $e');
    }
  }



@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Lists"),
          Text(
            "Drag to reorder",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
          ),
        ],
      ),
    ),
    body: GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Stack(
        children: [
    // Your main content goes here
    isLoading  // defined at the bottom of the page
        ? const Center(child: CircularProgressIndicator())
        : ReorderableListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: myTiles.length,
            onReorder: onReorder,
            itemBuilder: (context, index) {
              final tile = myTiles[index];
              return Padding(
                key: ValueKey(tile), // Important: Each item needs a unique key
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  color: Colors.grey[200],
                  child: ExpansionTile(
                    leading: Icon(Icons.drag_handle, color: Colors.grey[600]), // Drag handle icon
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
                            // Feedback Dialog Toggle with Liquid Glass Effect
                            FutureBuilder<bool>(
                              future: _getFeedbackDialogEnabled(tile),
                              builder: (context, snapshot) {
                                bool isEnabled = snapshot.data ?? true;
                                return Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                        child: Text(
                                          'Show feedback dialog',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () async {
                                          await _toggleFeedbackDialog(tile, !isEnabled);
                                          setState(() {});
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
                                              colors: isEnabled
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
                                                color: isEnabled
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
                                                alignment: isEnabled
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
                                );
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

        // Update the UI by fetching the updated list
        fetchTilesAsArray(userId).then((contacts) {
          if (mounted) {
            setState(() {
              myTiles = contacts;
            });
          }
        });

        print('$listName deleted');
      }
    } catch (e) {
      print('Error deleting contact: $e');
    }
  }


















}
