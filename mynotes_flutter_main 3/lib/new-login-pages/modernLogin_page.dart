import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/constants/routes.dart';
import 'package:flutter_application_1/new-login-pages/my_button_login.dart';
import 'package:flutter_application_1/new-login-pages/my_textfield.dart';

import 'package:flutter_application_1/utilities/dialogs/error_dialog.dart';




class LoginScreen1 extends StatefulWidget {
  const LoginScreen1({super.key});

  @override
  State<LoginScreen1> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginScreen1> {
 
  // text editing controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();









  // sign user in method
 Future<void> signUserIn() async {               
  final email = emailController.text;
  final password = passwordController.text;

  try {
    print("Attempting to sign in user: $email");

    final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email, 
      password: password,
    );

    print("User Credential: $userCredential");
    print("User: ${userCredential.user}");





    if (FirebaseAuth.instance.currentUser != null) {
      bool isEmailVerified = FirebaseAuth.instance.currentUser!.emailVerified;
      print("Email Verified: $isEmailVerified");

      if (isEmailVerified) {
        Navigator.of(context).pushNamedAndRemoveUntil(ListRoute, (route) => false);
      } else {
        showErrorDialog(context, "Verify Your Email");
      }
    }


  } on FirebaseAuthException catch (e) {
    print("FirebaseAuthException: ${e.code}");
    
    if (e.code == 'user-not-found') {
      await showErrorDialog(context, 'User not found');
    } else if (e.code == 'wrong-password'){
      await showErrorDialog(context, 'Wrong Username or Password');
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 50),

              // logo
              const Icon(
                Icons.lock,
                size: 100,
              ),

              const SizedBox(height: 50),

              // welcome back, you've been missed!
              Text(
                'Welcome back you\'ve been missed!',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 25),

              // email textfield
              MyTextField(
                controller: emailController,
                hintText: 'Email',
                obscureText: false,
              ),

              const SizedBox(height: 10),

              // password textfield
              MyTextField(
                controller: passwordController,
                hintText: 'Password',
                obscureText: true,
              ),

              const SizedBox(height: 10),

              // forgot password?
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Forgot Password?',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // sign in button
              MyButton(
                onTap: signUserIn,
              ),

              const SizedBox(height: 50),

              // or continue with
              // Padding(
              //   padding: const EdgeInsets.symmetric(horizontal: 25.0),
              //   child: Row(
              //     children: [
              //       Expanded(
              //         child: Divider(
              //           thickness: 0.5,
              //           color: Colors.grey[400],
              //         ),
              //       ),
              //       Padding(
              //         padding: const EdgeInsets.symmetric(horizontal: 10.0),
              //         child: Text(
              //           'Or continue with',
              //           style: TextStyle(color: Colors.grey[700]),
              //         ),
              //       ),
              //       Expanded(
              //         child: Divider(
              //           thickness: 0.5,
              //           color: Colors.grey[400],
              //         ),
              //       ),
              //     ],
              //   ),
              // ),

              const SizedBox(height: 50),

              // google + apple sign in buttons
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.center,
              //   children: const [
              //     // google button
              //     SquareTile(imagePath: 'lib/new-login-pages/images/google.png'),

              //     SizedBox(width: 25),

              //     // apple button
              //     SquareTile(imagePath: 'lib/new-login-pages/images/apple.png')
              //   ],
              // ),

              const SizedBox(height: 50),

              // not a member? register now
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Not a member?',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(width: 4),

                  TextButton(
                    onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/register/', 
                  (route) => false
                  );
                    },
                    child: Text(
                      'Register now',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}


