// import 'package:alan_voice/alan_voice.dart';
// import 'package:flutter/material.dart';
// //import 'package:flutter_application_1/views/dialer/dialer_backup.dart';
// import 'package:flutter_application_1/views/list/firebase_services.dart';
// import 'package:flutter_application_1/views/list/list_view_backup_file.dart';
// import 'package:flutter_application_1/views/notes/notes_view.dart';

// class MyHomePage extends StatefulWidget {
//   @override
//   _MyHomePageState createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   @override
//   void initState() {
//     super.initState();

//     /// Init Alan Button with project key from Alan AI Studio
//     AlanVoice.addButton("d910f09071fca127bf5eb950f7359f672e956eca572e1d8b807a3e2338fdd0dc/stage");

//     /// Handle commands from Alan AI Studio
//     AlanVoice.onCommand.add((command) {
//       debugPrint("got new command ${command.toString()}");
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Alan AI Home Page'),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text(
//               'Welcome to Alan AI Home Page!',
//               style: TextStyle(fontSize: 20),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(builder: (context) => AlanPage()),
//                 );
//               },
//               child: Text('Go to Alan Page'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class AlanPage extends StatefulWidget {
//   @override
//   _AlanPageState createState() => _AlanPageState();
// }

// class _AlanPageState extends State<AlanPage> {
//   @override
//   void initState() {
//     super.initState();

//     /// Initializing Alan AI with the provided project id
//     AlanVoice.addButton(
//       "d910f09071fca127bf5eb950f7359f672e956eca572e1d8b807a3e2338fdd0dc/stage",
//     );

//     /// Handle commands from Alan AI Studio
//     AlanVoice.onCommand.add((command) {
//       debugPrint("got new command ${command.toString()}");
//       // You can perform specific actions based on the received commands here
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Alan AI Page'),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text(
//               'Welcome to Alan AI Page!',
//               style: TextStyle(fontSize: 20),
//             ),
//             SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: () {
//                 // You can trigger Alan AI commands here
//                 AlanVoice.playText("Hello from Alan AI!");
//               },
//               child: Text('Press Me'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     AlanVoice.removeButton();
//     super.dispose();
//   }
// }