import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/views/dialer/dialer.dart';
import 'package:flutter_application_1/views/list/firebase_services.dart';
import 'package:flutter_application_1/utilities/apple_typography.dart';
import 'package:cupertino_native/cupertino_native.dart';


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
    _initializeAndFetch();
  }

  Future<void> _initializeAndFetch() async {
    // Firebase is already initialized in home_page.dart, no need to re-initialize
    try {
      final contacts = await fetchTilesAsArray(userId);
      // Load descriptions for each list
      for (String listName in contacts) {
        String? description = await getListDescription(listName);
        descriptionControllers[listName] = TextEditingController(text: description ?? '');
      }
      
      if (mounted) {
        setState(() {
          myTiles = contacts;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching tiles: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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
      // Get contact count from Contact Directories (new normalized structure)
      final contactCount = await getContactCountForList(listName);

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
        'count': contactCount,
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
    backgroundColor: const Color.fromRGBO(248, 248, 250, 1),
    body: SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lists',
                  style: AppleTypography.withAppleFont(
                    AppleTypography.headline3.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color.fromRGBO(64, 105, 225, 1),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Drag to reorder',
                  style: AppleTypography.withAppleFont(
                    AppleTypography.body2.copyWith(color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
              },
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
                                'Loading lists...',
                                style: AppleTypography.withAppleFont(
                                  AppleTypography.body1.copyWith(color: Colors.grey.shade600),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                          itemCount: myTiles.length,
                          onReorder: onReorder,
                          buildDefaultDragHandles: false,
                          proxyDecorator: (child, index, animation) {
                            return Material(
                              color: Colors.transparent,
                              child: child,
                            );
                          },
                          itemBuilder: (context, index) {
                            final tile = myTiles[index];
                            return Padding(
                              key: ValueKey(tile),
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                clipBehavior: Clip.antiAlias,
                                elevation: 1,
                                shadowColor: Colors.black.withOpacity(0.1),
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                    dividerColor: Colors.transparent,
                                    splashColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                  ),
                                  child: ExpansionTile(
                                    initiallyExpanded: false,
                                    maintainState: false,
                                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                    leading: ReorderableDragStartListener(
                                      index: index,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(Icons.drag_handle, color: Colors.grey.shade600),
                                      ),
                                    ),
                                    title: Text(
                                      tile,
                                      style: AppleTypography.withAppleFont(
                                        AppleTypography.subtitle1.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CNButton.icon(
                                          icon: const CNSymbol('person.2.fill', size: 20),
                                          style: CNButtonStyle.prominentGlass,
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) => DialerContactsView(listName: tile),
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        IgnorePointer(
                                          child: Opacity(
                                            opacity: 0.5,
                                            child: CNButton.icon(
                                              icon: const CNSymbol('info.circle', size: 20),
                                              style: CNButtonStyle.prominentGlass,
                                              onPressed: () {},
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  children: [
                                    TextField(
                                      controller: descriptionControllers[tile],
                                      decoration: InputDecoration(
                                        hintText: 'Enter list description',
                                        hintStyle: AppleTypography.withAppleFont(
                                          AppleTypography.body2.copyWith(color: Colors.grey.shade500),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                            color: Color.fromRGBO(64, 105, 225, 1),
                                            width: 2,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                      ),
                                      maxLines: 3,
                                      onChanged: (value) {
                                        updateListDescription(tile, value);
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    FutureBuilder(
                                      future: _getListStats(tile),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          final stats = snapshot.data as Map<String, dynamic>;
                                          return Row(
                                            children: [
                                              Expanded(
                                                child: Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: const Color.fromRGBO(64, 105, 225, 0.08),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Contacts',
                                                        style: AppleTypography.withAppleFont(
                                                          AppleTypography.caption.copyWith(color: Colors.grey.shade600),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '${stats['count']}',
                                                        style: AppleTypography.withAppleFont(
                                                          AppleTypography.subtitle1.copyWith(
                                                            fontWeight: FontWeight.w600,
                                                            color: const Color.fromRGBO(64, 105, 225, 1),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Last dialed',
                                                        style: AppleTypography.withAppleFont(
                                                          AppleTypography.caption.copyWith(color: Colors.grey.shade600),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '${stats['lastDialed'] ?? 'Never'}',
                                                        style: AppleTypography.withAppleFont(
                                                          AppleTypography.body2.copyWith(
                                                            fontWeight: FontWeight.w600,
                                                            color: Colors.grey.shade800,
                                                          ),
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }
                                        return const Center(
                                          child: SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color.fromRGBO(64, 105, 225, 1),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed: () {
                                          deleteSpecificContact(tile);
                                        },
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        label: Text(
                                          'Delete',
                                          style: AppleTypography.withAppleFont(
                                            AppleTypography.body2.copyWith(color: Colors.red),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  onExpansionChanged: (expanded) {
                                    if (expanded) {
                                      _animationController.forward();
                                      FocusScope.of(context).unfocus();
                                    } else {
                                      _animationController.reverse();
                                    }
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  Positioned(
                    bottom: 30,
                    right: 30,
                    child: CNButton.icon(
                      icon: const CNSymbol('plus', size: 22),
                      style: CNButtonStyle.prominentGlass,
                      onPressed: () async {
                        await showListDialog(context);
                        fetchTilesAsArray(userId).then((contacts) {
                          setState(() {
                            myTiles = contacts;
                            isLoading = false;
                          });
                        });
                      },
                    ),
                  ),
                ],
              ),
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
