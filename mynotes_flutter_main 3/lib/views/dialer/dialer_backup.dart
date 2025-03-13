
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_application_1/views/dialer/dialer_contacts_view.dart';

// //import 'package:flutter_application_1/views/dialer/dialer_backup.dart';
// import 'package:flutter_application_1/views/list/firebase_services.dart';
// import 'package:flutter_application_1/views/list/list_view.dart';


// import '../../enums/menu_action.dart';
// import '../../utilities/dialogs/logout_dialog.dart';


// // These are the functions for the card ui ...

// class ImgSample {
//   static String get(String imageName) {
//     return "asses/image/$imageName";
//   }
// }




// class MyStringsSample {
//   static const String card_text =
//       "This is a sample card description. You can replace it with your own text.";
// }

// class MyColorsSample {
//   static const Color accent = Colors.blue; // Replace with your desired color
// }









// class DialerView extends StatelessWidget {

//   const DialerView({Key? key}) : super(key: key);









//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Dialer View'),
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
//         child: DialButton(),
//       ),
      
//        //bottomNavigationBar: Gbar(),
       
//     );
//   }
// }

// class DialButton extends StatelessWidget {




 
















//   final bool _isPressed = false;


// //  @override
// //  void initState() {
   
    
// //  }

// // Card variables
// double defaultRadius = 8.0;
// final double _cardWidth = 115;

//   DialButton({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(


      
//   //     floatingActionButton: ElevatedButton(
//   //       style: ElevatedButton.styleFrom(
//   //   primary: Colors.grey[200], // Set to your background color
//   //   onPrimary: Colors.grey[200], // Set to your background color
//   //   shape: RoundedRectangleBorder(
//   //     borderRadius: BorderRadius.circular(8.0),
//   //   ),
//   //   padding: const EdgeInsets.all(12.0),
//   // ),
//   //       child: Icon(Icons.add, size:30, color: textColor(context)),
//   //       onPressed:() {},
//   //     ),



//       backgroundColor: const Color.fromRGBO(248, 225, 209, 1),
//       body: Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: <Widget>[



              

// // ElevatedButton(
// //   onPressed: () async {
// //     fetchDocumentAtIndexAndShowDialog(context, index, selectedList);
// //   },
// //   style: ElevatedButton.styleFrom(
// //     primary: Colors.grey[200], // Background color
// //     shape: RoundedRectangleBorder(
// //       borderRadius: BorderRadius.circular(8.0),
// //     ),
// //     padding: const EdgeInsets.all(12.0),
// //   ),
// //   child: Text(
// //     "Dial $selectedList",
// //     style: TextStyle(color: textColor(context)),
// //   ),
// // ),

// // ElevatedButton(
// //   onPressed: () async {
// //    Navigator.of(context).push(
// //     MaterialPageRoute(
// //       builder: (context) =>  MyHomePage(),
// //     ),
// //   );
// //   },
// //   style: ElevatedButton.styleFrom(
// //     primary: Colors.grey[200], // Background color
// //     shape: RoundedRectangleBorder(
// //       borderRadius: BorderRadius.circular(8.0),
// //     ),
// //     padding: const EdgeInsets.all(12.0),
// //   ),
// //   child: Text(
// //     "Go To Alan Voice",
// //     style: TextStyle(color: textColor(context)),
// //   ),
// // ),

// //   ElevatedButton(
// //   onPressed: () async {
// //     index = 0;
// //   },
// //   style: ElevatedButton.styleFrom(
// //     primary: Colors.grey[200], // Set to your background color
// //     onPrimary: Colors.grey[200], // Set to your background color
// //     shape: RoundedRectangleBorder(
// //       borderRadius: BorderRadius.circular(8.0),
// //     ),
// //     padding: const EdgeInsets.all(12.0),
// //   ),
// //   child: Text(
// //     "Reset Call Cycle Index",
// //     style: TextStyle(color: textColor(context)),
// //   ),
// // ),


// // Padding(
// //   padding: const EdgeInsets.all(12.0),
// //   child:   Text(
// //     "Contacts in $selectedList: $listContactsJoinedforDialerView",
   
// //   ),
// // ),



// // Card..

// Row(
//    children: <Widget>[ 
//     Expanded( 
//       child: Card(
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               clipBehavior: Clip.antiAliasWithSaveLayer,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: <Widget>[
//                   // Image.asset(
//                   //   ImgSample.get('relaxing-man.png'),
//                   //   height: 160,
//                   //   width: double.infinity,
//                   //   fit: BoxFit.cover,
//                   // ),
//                   Container(
//                     padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: <Widget>[
//                         Text(
//                           "Dial List",
//                           style: TextStyle(
//                             fontSize: 24,
//                             color: Colors.grey[800],
//                           ),
//                         ),
//                         Container(height: 10),
//                         Text(
//                           "Start the call cycle for $selectedList by pressing dial, or reset the index and start the list from the start again! ",
//                           style: TextStyle(
//                             fontSize: 15,
//                             color: Colors.grey[700],
//                           ),
//                         ),
//                         Row(
//                           children: <Widget>[
//                             const Spacer(),
//                             TextButton(
//                               style: TextButton.styleFrom(
//                                 foregroundColor: Colors.transparent,
//                               ),
//                               child: const Text(
//                                 "Dial",
//                                 style: TextStyle(color: MyColorsSample.accent),
//                               ),
//                               onPressed: () async{
//                                 fetchDocumentAtIndexAndShowDialog(context, index, selectedList);
//                               },
//                             ),
//                             TextButton(
//                               style: TextButton.styleFrom(
//                                 foregroundColor: Colors.transparent,
//                               ),
//                               child: const Text(
//                                 "Start again!",
//                                 style: TextStyle(color: MyColorsSample.accent),
//                               ),
//                               onPressed: () async {
//                                   index = 0;
//                               },
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                   Container(height: 5),
//                 ],
//               ),
//             ),
//             ),
//                   TextButton(
//                     style: TextButton.styleFrom(
//                       foregroundColor: Colors.transparent,
//                     ),
//                     child: const Text(
//                       "Guide",
//                       style: TextStyle(color: MyColorsSample.accent),
//                     ),
//                     onPressed: () async {
//                       Navigator.of(context).push(
//                         MaterialPageRoute(
//                           builder: (context) => DialerContactsView(listName: selectedList), // Pass the listName here
//                         ),
//                       );  
//                     },
//                   ),
            
//             ],
        

            
//             ),





//           ],
//         ),
//       ),
//     );
//   }
// }