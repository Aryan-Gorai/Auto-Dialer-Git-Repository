// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter_application_1/constants/routes.dart';
// import 'package:flutter_application_1/firebase_options.dart';
// import 'package:flutter_application_1/utilities/dialogs/error_dialog.dart';
// import 'package:flutter_application_1/views/list/list_view.dart';

// class RegisterScreen1 extends StatefulWidget {
//   const RegisterScreen1({super.key});

//   @override
//   State<RegisterScreen1> createState() => _RegisterScreen1State();
// }

// class _RegisterScreen1State extends State<RegisterScreen1> {

// late final TextEditingController _email;
// late final TextEditingController _password;


// @override
// void initState() {
//   _email = TextEditingController();
//   _password = TextEditingController();
//   super.initState();
// }


// @override
// void dispose() {
//   _email.dispose();
//   _password.dispose();
//   super.dispose();
// }




//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Register View")),
//       body: Column(
//             children: [
        
        
//               TextField(
//                 controller: _email,
//                 enableSuggestions: false,
//                 autocorrect: false,
//                 keyboardType: TextInputType.emailAddress,
//                 decoration: InputDecoration(
//                   hintText: 'Enter your email address'
//                 ),
//               ),
        
        
        
//               TextField(
//                 controller: _password,
//                 obscureText: true,
//                 enableSuggestions: false,
//                 autocorrect: false,
//                 decoration: InputDecoration(
//                   hintText: 'Enter your password'
//                 ),
//                 ),
        
        
        
//               TextButton(onPressed: () async {
//                final email = _email.text;
//                final password = _password.text;
//                 try { final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
//                 email: email, 
//                 password: password,
//                 );
//                 print(userCredential);
                
//                 Navigator.of(context).pushNamedAndRemoveUntil(
//                   '/VerifyEmail/', 
//                 (route) => false,
//                 );

//                 } on FirebaseAuthException catch (e) {
//                   if (e.code == 'weak-password') {
//                     await showErrorDialog(context, 'Weak Password. Needs to be => 6 characters');
//                   }
//                   else if (e.code == 'email-already-in-use') {
//                     await showErrorDialog(context, 'Email is already in use');
//                   }
//                   else if (e.code == "invalid-email") {
//                     await showErrorDialog(context, 'Invalid Email');
//                   } else {
//                     await showErrorDialog(context, 'Authentication/Internet error');
//                   }
//                 }


//                // createDemoList();
              
//               },
//               child: const Text('Register') ,
//               ),

//               TextButton(onPressed: () {
//                 Navigator.of(context).pushNamedAndRemoveUntil(
//                   '/login/', 
//                 (route) => false
//                 );
//               },
//               child: const Text('Already registered? Login Here!'),
//               )

//             ],
//           ),
//     );

//   }
//   }
