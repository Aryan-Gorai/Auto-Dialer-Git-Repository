// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';

// class DialerContactsView extends StatefulWidget {
//   final String listName;

//   const DialerContactsView({Key? key, required this.listName}) : super(key: key);

//   @override
//   State<DialerContactsView> createState() => _DialerContactsViewState();
// }

// class _DialerContactsViewState extends State<DialerContactsView> {
//   List<String> myTiles = [];
//   bool isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     fetchContactsAsArray(widget.listName).then((contacts) {
//       setState(() {
//         myTiles = contacts;
//         isLoading = false;
//       });
//       updateContactIndices();
//     });
//   }
//   Future<List<String>> fetchContactsAsArray(String selectedList) async {
    
//     FirebaseFirestore firestore = FirebaseFirestore.instance;
//     QuerySnapshot snapshot = await firestore
//         .collection('lists')
//         .where('list_name', isEqualTo: selectedList)
//         .orderBy("contact_index")
//         .get();

//     List<String> listContacts = snapshot.docs.map((doc) {
//       return doc.get('contact_name') as String;
//     }).toList();



//   print(listContacts);
//     return listContacts;
    
//   }

//   Future<void> updateContactIndices() async {
//     FirebaseFirestore firestore = FirebaseFirestore.instance;
//     WriteBatch batch = firestore.batch();

//     for (int i = 0; i < myTiles.length; i++) {
//       String contactName = myTiles[i];
//       QuerySnapshot snapshot = await firestore
//           .collection('lists')
//           .where('list_name', isEqualTo: widget.listName)
//           .where('contact_name', isEqualTo: contactName)
//           .get();

//       if (snapshot.docs.isNotEmpty) {
//         DocumentReference docRef = snapshot.docs.first.reference;
//         batch.update(docRef, {'contact_index': i});
//       }
//     }

//     await batch.commit();
//   }

//   void updateMyTiles(int oldIndex, int newIndex) {
//     setState(() {
//       if (oldIndex < newIndex) {
//         newIndex -= 1;
//       }
//       final String tile = myTiles.removeAt(oldIndex);
//       myTiles.insert(newIndex, tile);
//     });
//     updateContactIndices();
//   }
// @override
// Widget build(BuildContext context) {
//   return Scaffold(
//     appBar: AppBar(title: Text("Contacts in ${widget.listName}")),
//     body: Stack(
//       children: [
//         // Your main content goes here
//         isLoading
//             ? const Center(child: CircularProgressIndicator())
//             : ReorderableListView(
//                 padding: const EdgeInsets.all(10),
//                 children: [
//                   for (final tile in myTiles)
//                     Padding(
//                       key: ValueKey(tile),
//                       padding: const EdgeInsets.all(8.0),
//                       child: Container(
//                         color: Colors.grey[200],
//                         child: ListTile(
//                           title: Text(tile),
//                         ),
//                       ),
//                     ),
//                 ],
//                 onReorder: (oldIndex, newIndex) {
//                   updateMyTiles(oldIndex, newIndex);
//                 },
//               ),
//         // First FloatingActionButton
//         Positioned(
//           bottom: 200, // Padding from the bottom
//           right: 30, // Padding from the right
//           child: FloatingActionButton(
//             onPressed: () {
//               // Action for the first button
//               print('First FloatingActionButton pressed');
//             },
//             child: Icon(Icons.add),
//             tooltip: 'Add Contact',
//           ),
//         ),
//         // Second FloatingActionButton
//         Positioned(
//           bottom: 130, // Padding from the bottom (stacked above the first button)
//           right: 30, // Same right padding to align with the first button
//           child: FloatingActionButton(
//             onPressed: () {
//               // Action for the second button
//               print('Second FloatingActionButton pressed');
//             },
//             child: Icon(Icons.call),
//             tooltip: 'Edit Contact',
//           ),
//         ),
//         Positioned(
//           bottom: 60, // Padding from the bottom (stacked above the first button)
//           right: 30, // Same right padding to align with the first button
//           child: FloatingActionButton(
//             onPressed: () {
//               // Action for the second button
//               print('Second FloatingActionButton pressed');
//             },
//             child: Icon(Icons.replay_outlined),
//             tooltip: 'Edit Contact',
//           ),
//         ),
//       ],
//     ),
//   );
// }
// }