// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter_application_1/constants/routes.dart';
// import 'package:flutter_application_1/firebase_options.dart';
// import 'package:flutter_application_1/views/list/list_view.dart';

// import '../utilities/dialogs/error_dialog.dart';

// class LoginScreen1 extends StatefulWidget {
//   const LoginScreen1({Key? key}) : super(key: key);

//   @override
//   State<LoginScreen1> createState() => _LoginViewState();
// }


// class _LoginViewState extends State<LoginScreen1> {


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
//       appBar: AppBar(title: const Text ('Login'),),
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
    
//                 try {
                  
//                 final userCredential = await (
//                 email: email, 
//                 password: password,
//                 );




//                   if (FirebaseAuth.instance.currentUser != null) {
//                     bool isEmailVerified = FirebaseAuth.instance.currentUser!.emailVerified;

//                     if (isEmailVerified) {
//                       Navigator.of(context).pushNamedAndRemoveUntil(ListRoute, (route) => false);
//                     } else {
//                       Navigator.of(context).pushNamedAndRemoveUntil('/VerifyEmail/', (route) => false);
//                     }
//                   } else {
//                     // Handle the case where there is no current user. You may want to sign the user in first.
//                     // Example:
//                     // Navigator.of(context).pushReplacementNamed(SignInRoute);
//                   }



    
//                 } on FirebaseAuthException catch (e) {
//                   if (e.code == 'user-not-found') {
//                     await showErrorDialog(context, 'User not found');
//                   } else if (e.code == 'wrong-password'){
//                     await showErrorDialog(context, 'Wrong User Name or Password');
//                   }
    
//                 }

                
//                 //createDemoList();
                
    
    
//               },
//               child: const Text('Login') ,
//               ),
//               TextButton(
//                 onPressed: () {
//                   Navigator.of(context).pushNamedAndRemoveUntil(
//                     '/register/', 
//                   (route) => false
//                   );
//                 },
//                 child: const Text('Note registered yet? Register here!'),
//               ),
//             ],
//       ),
//      );
    

//   }
//   }