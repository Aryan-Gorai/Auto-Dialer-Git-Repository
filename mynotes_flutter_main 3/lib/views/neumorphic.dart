// import 'package:flutter/material.dart';
// import 'package:flutter/src/widgets/framework.dart';
// import 'package:flutter/src/widgets/placeholder.dart';


// class neumorphicView extends StatefulWidget {
//   const neumorphicView({super.key});

//   @override
//   State<neumorphicView> createState() => _neumorphicViewState();
// }

// class _neumorphicViewState extends State<neumorphicView> {
//   bool _isElevated = false;
  
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar:  AppBar(
//         title: const Text ('Neumorphic Style')
//       ),
//       backgroundColor: Colors.grey[300],
//       body: Center(
//         child: GestureDetector(
//           onTap: () {
//             _isElevated = !_isElevated;
//           },
//           child: AnimatedContainer(
//             duration: const Duration(milliseconds:200),
//             height: 200,
//             width: 200,
//             decoration: BoxDecoration(
//               color: Colors.grey[300],
//               borderRadius: BorderRadius.circular(50),
//               boxShadow: _isElevated 
//               ?[
//                 BoxShadow(
//                 color: Colors.grey[500]!,
//                 offset: const Offset(4,4),
//                 blurRadius: 15,
//                 spreadRadius: 1,
//                 ),
//                 const BoxShadow(
//                 color: Colors.white,
//                 offset: Offset(-4,-4),
//                 blurRadius: 15,
//                 spreadRadius: 1,
//                 ),
//               ]
//               :null,
//             ),
//           ),
//         )
//       ),
//     );
//   }
// }