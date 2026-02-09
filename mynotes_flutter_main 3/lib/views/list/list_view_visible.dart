// Main list display screen used in the slider/tab bar.
// Shows all of the user's contact lists as expandable tiles, with contacts
// inside each tile. Supports drag-to-reorder (updates manual_order in
// Firestore), navigating into the dialer for a specific list, and
// pulling contacts from the normalised Contact Directories collection.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/views/dialer/dialer.dart';
import 'package:flutter_application_1/views/list/firebase_services.dart';
import 'package:flutter_application_1/theme/components/app_components.dart';


class list_view_visible extends StatefulWidget {
  const list_view_visible({super.key});

  @override
  State<list_view_visible> createState() => _list_view_visibleState();
}



    List<String> myTiles = [];
  // Fetches all list names for this user from Firestore.
  // Sorts by manual_order (if drag-reordered) or list_order timestamp.
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



// Navigates into the DialerContactsView for whichever list the user tapped.
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
  final Map<String, ExpansionTileController> _expansionControllers = {};
  final Set<String> _expandedTiles = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _initializeAndFetch();
  }

  // Bootstraps the page — loads tiles from Firestore and pre-creates
  // a TextEditingController for each list's description field.
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

  // Reads the description text for a single list from Firestore.
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

  // Saves an edited description back to the list's Firestore doc.
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
    backgroundColor: AppDesignTokens.scaffoldBg,
    body: SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lists',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppDesignTokens.neutral900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Drag to reorder calling queues',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppDesignTokens.neutral500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AppPrimaryButton(
                  label: 'New list',
                  icon: Icons.add,
                  height: 40,
                  expanded: false,
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
              ],
            ),
          ),
          // Content
          Expanded(
            child: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
              },
              child: isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            color: AppDesignTokens.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading lists...',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppDesignTokens.neutral500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
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
                        _expansionControllers.putIfAbsent(tile, () => ExpansionTileController());
                        final expansionController = _expansionControllers[tile]!;
                        return Padding(
                          key: ValueKey(tile),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppDesignTokens.surface,
                              borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                              border: Border.all(color: AppDesignTokens.neutral200),
                              boxShadow: AppDesignTokens.cardShadow,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                dividerColor: Colors.transparent,
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                              ),
                              child: ExpansionTile(
                                controller: expansionController,
                                initiallyExpanded: false,
                                maintainState: false,
                                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                leading: ReorderableDragStartListener(
                                  index: index,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppDesignTokens.neutral100,
                                      borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                                    ),
                                    child: const Icon(Icons.drag_handle, color: AppDesignTokens.neutral500),
                                  ),
                                ),
                                title: Text(
                                  tile,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppDesignTokens.neutral900,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AppIconButton(
                                      icon: Icons.people_outline,
                                      iconColor: AppDesignTokens.primary,
                                      backgroundColor: AppDesignTokens.primarySoft,
                                      size: 38,
                                      tooltip: 'View contacts',
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => DialerContactsView(listName: tile),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    AppIconButton(
                                      icon: Icons.info_outline,
                                      iconColor: AppDesignTokens.neutral500,
                                      backgroundColor: AppDesignTokens.neutral100,
                                      size: 38,
                                      tooltip: 'Details',
                                      onPressed: () {
                                        if (_expandedTiles.contains(tile)) {
                                          expansionController.collapse();
                                        } else {
                                          expansionController.expand();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              children: [
                                // Description field
                                TextField(
                                  controller: descriptionControllers[tile],
                                  decoration: InputDecoration(
                                    hintText: 'Enter list description',
                                    hintStyle: const TextStyle(
                                      fontSize: 14,
                                      color: AppDesignTokens.neutral400,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                                      borderSide: const BorderSide(color: AppDesignTokens.neutral300),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                                      borderSide: const BorderSide(color: AppDesignTokens.neutral300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                                      borderSide: const BorderSide(
                                        color: AppDesignTokens.primary,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: AppDesignTokens.neutral50,
                                  ),
                                  maxLines: 3,
                                  onChanged: (value) {
                                    updateListDescription(tile, value);
                                  },
                                ),
                                const SizedBox(height: 16),
                                // Stats tiles
                                FutureBuilder(
                                  future: _getListStats(tile),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      final stats = snapshot.data as Map<String, dynamic>;
                                      return Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              padding: const EdgeInsets.all(14),
                                              decoration: BoxDecoration(
                                                color: AppDesignTokens.primary.withOpacity(0.06),
                                                borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                                                border: Border.all(color: AppDesignTokens.primary.withOpacity(0.15)),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Contacts',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                      color: AppDesignTokens.neutral600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${stats['count']}',
                                                    style: const TextStyle(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppDesignTokens.primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Container(
                                              padding: const EdgeInsets.all(14),
                                              decoration: BoxDecoration(
                                                color: AppDesignTokens.neutral100,
                                                borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                                                border: Border.all(color: AppDesignTokens.neutral200),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Last dialed',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                      color: AppDesignTokens.neutral600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${stats['lastDialed'] ?? 'Never'}',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppDesignTokens.neutral800,
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
                                          color: AppDesignTokens.primary,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 14),
                                // Delete button
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      deleteSpecificContact(tile);
                                    },
                                    icon: const Icon(Icons.delete_outline, color: AppDesignTokens.danger, size: 18),
                                    label: const Text(
                                      'Delete list',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppDesignTokens.danger,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              onExpansionChanged: (expanded) {
                                if (expanded) {
                                  _expandedTiles.add(tile);
                                  _animationController.forward();
                                  FocusScope.of(context).unfocus();
                                } else {
                                  _expandedTiles.remove(tile);
                                  _animationController.reverse();
                                }
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ),
        ],
      ),
    ),
  );
}




  // Removes a list doc from lists_collection and refreshes the tile grid.
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
