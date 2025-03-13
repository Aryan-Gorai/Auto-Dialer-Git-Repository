// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_application_1/enums/menu_action.dart';
// import 'package:flutter_application_1/utilities/dialogs/logout_dialog.dart';
// import '../dialer/dialer.dart';
// import '../list/firebase_services.dart';
// import 'bar_graph/bar_graph.dart';

// class ReportsView extends StatefulWidget {
//   const ReportsView({Key? key}) : super(key: key);

//   @override
//   State<ReportsView> createState() => _ReportsViewState();
// }

// class _ReportsViewState extends State<ReportsView> {


//    @override
//   void initState() {
//     super.initState();
//     fetchALLData();
//   }


//   List<double> weeklySummary = [];
//   List<double> listIndexDouble = [];
//   List<double> listTotalDocumentsDouble = [];
//   List<double> listPercentages = [];
//   List<String> listNames = [];

//   bool shouldShowGraph = false;



//   Future<List<double>> fetchALLData() async {
//     await getListIndex();
//     await getListTotalDocuments();
//     await calculatePercentages();
//     await getListNames();
//     return weeklySummary;
//   }




//  Future<void> calculatePercentages() async {
//   if (listIndexDouble.length != listTotalDocumentsDouble.length) {
//     print("Error: Arrays have different lengths.");
//     return;
//   }

//   List<double> newWeeklySummary = [];

//   for (int i = 0; i < listIndexDouble.length; i++) {
//     if (listTotalDocumentsDouble[i] != 0) {
//       double newValue = (listIndexDouble[i] / listTotalDocumentsDouble[i]) * 100;
//       newWeeklySummary.add(newValue);
//     } else {
//       newWeeklySummary.add(0);
//     }
//   }

//   setState(() {
//     weeklySummary = newWeeklySummary;
//   });

//   print("Weekly Summary: $weeklySummary");
// }




//   Future<void> getListNames() async {
//     //FirebaseFirestore firestore = FirebaseFirestore.instance;
//     //QuerySnapshot snapshot = await firestore.collection('lists_collection').get();


//         QuerySnapshot snapshot = await FirebaseFirestore.instance
//         .collection('lists_collection')
//         .where('user_id', isEqualTo: userId)
//         .get();


//     List<String> names = snapshot.docs.map((DocumentSnapshot doc) {
//       return doc.get('list_name') as String;
//     }).toList();
    

//     setState(() {
//       listNames = names;
//     });
//   }













//   Future<void> getListIndex() async {
//     FirebaseFirestore firestore = FirebaseFirestore.instance;
//     //QuerySnapshot snapshot = await firestore.collection('lists_collection').get();

//         QuerySnapshot snapshot = await FirebaseFirestore.instance
//         .collection('lists_collection')
//         .where('user_id', isEqualTo: userId)
//         .get();



//     List<int> listIndex = snapshot.docs.map((DocumentSnapshot doc) {
//       return doc.get('current_index') as int;
//     }).toList();

//     // Convert the listIndex values to double and update weeklySummary
//     // weeklySummary = listIndex.map((int value) => value.toDouble()).toList();
//     listIndexDouble = listIndex.map((int value) => value.toDouble()).toList();

//     print(listIndex);

//     // Trigger a rebuild of the UI
//     setState(() {});
//   }


//   List<int> listTotalDocuments = [];
//   Future<void> getListTotalDocuments() async {
//     FirebaseFirestore firestore = FirebaseFirestore.instance;
//     //QuerySnapshot snapshot = await firestore.collection('lists_collection').get();

//         QuerySnapshot snapshot = await FirebaseFirestore.instance
//         .collection('lists_collection')
//         .where('user_id', isEqualTo: userId)
//         .get();




//     List<int> index = snapshot.docs.map((DocumentSnapshot doc) {
//       return doc.get('total_documents') as int;
//     }).toList();

      
//       listTotalDocuments = index;
//       listTotalDocumentsDouble = listTotalDocuments.map((int value) => value.toDouble()).toList();

//       print(listTotalDocuments);
//     setState(() {
     
//     });
//   }





//   void toggleGraphVisibility() {
//     setState(() {
//       shouldShowGraph = !shouldShowGraph;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       bottomNavigationBar: Gbar(),
//       backgroundColor: Color.fromRGBO(248, 225, 209, 1),
      
//       appBar: AppBar(
//         title: Text("Reports View (% Completion)"),
//         actions: [
//           PopupMenuButton(
//             onSelected: (value) async {
//               switch (value){

//                 case MenuAction.logout:
//                   final shouldLogout = await showLogOutDialog(context);
//                   if (shouldLogout) {
//                     await FirebaseAuth.instance.signOut();
//                     Navigator.of(context).pushNamedAndRemoveUntil(
//                       '/login/',
//                     (_) => false,
//                     );
//                   }
//               }
//             },
//             itemBuilder: (context) {
//               return const [  
//                  PopupMenuItem<MenuAction>(

//                 value: MenuAction.logout, 
//                 child: Text("Log out"),
              
//               ),
//         ]; 
                

//             }
//           ),
//         ],
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [



//             ElevatedButton(
//               onPressed: toggleGraphVisibility,
//               style: ElevatedButton.styleFrom(
//                 primary: Colors.grey[200], // Background color
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8.0),
//                 ),
//                 padding: const EdgeInsets.all(12.0),
//               ),
//               child: Text(
//                 "Draw Graph",
//                 style: TextStyle(color: textColor(context)),
//               ),
//             ),





//             ElevatedButton(
//               onPressed: () async {
                        
//                 setState(() {
//                   shouldShowGraph = false;
//                 });
//                 fetchALLData();
//               },
//               style: ElevatedButton.styleFrom(
//                 primary: Colors.grey[200], // Background color
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8.0),
//                 ),
//                 padding: const EdgeInsets.all(12.0),
//               ),
//               child: Text(
//                 "Get List Data",
//                 style: TextStyle(color: textColor(context)),
//               ),
//             ),




//             if (shouldShowGraph)
//               SizedBox(
//                 height: 400,
//                 child: MyBarGraph(weeklySummary: weeklySummary),
//               ),
//                SizedBox(height: 20), // Add spacing between buttons and listNames display
//             if (listNames.isNotEmpty)
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: List.generate(
//                   listNames.length,
//                   (index) => Text("$index: ${listNames[index]}"),
//                 ),
//               )
//         ],
//         ),
//       ),
//     );
//   }
// }
