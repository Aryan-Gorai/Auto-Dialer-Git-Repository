// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';

// class VerifyEmailView2 extends StatefulWidget {
//   const VerifyEmailView2({super.key});

//   @override
//   State<VerifyEmailView2> createState() => _VerifyEmailView2State();
// }

// class _VerifyEmailView2State extends State<VerifyEmailView2> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//        appBar: AppBar(title: Text("Verify Email View")),
//       body: Column(
//         children: [
//           Text("Please Verify your email address, an email has already been sent, only click the button below if you have not recieved it. Please remember to check spam! Once Verified, return to login page and login again."),
//           TextButton(
//             onPressed: () async {
//               final user = FirebaseAuth.instance.currentUser;
//               await user?.sendEmailVerification();
//           },
//           child: const Text('Send email Verification'),
//           ),
//           TextButton(
//             onPressed: () async {
//             Navigator.of(context).pushNamedAndRemoveUntil(
//                   '/login/', 
//                 (route) => false,
//                 );
//           },
//           child: const Text('Return to Login Page'),
//           ),
//         ],
//         ),
//     );
//   }
// }