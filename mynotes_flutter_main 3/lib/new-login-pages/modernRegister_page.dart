import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:flutter_application_1/new-login-pages/my_button_register.dart';
import 'package:flutter_application_1/new-login-pages/my_textfield.dart';

import 'package:flutter_application_1/new-login-pages/verifyEmailDialog.dart';
import 'package:flutter_application_1/utilities/dialogs/error_dialog.dart';
import 'package:flutter_application_1/views/list/list_view.dart';



class RegisterScreen1 extends StatefulWidget {
  const RegisterScreen1({super.key});

  @override
  State<RegisterScreen1> createState() => _LoginPageState();
}

class _LoginPageState extends State<RegisterScreen1> {
 
  // text editing controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();









  // sign user in method
  Future<void> registerUser() async {               
    
              final email = emailController.text;
               final password = passwordController.text;
    
                try { final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                email: email, 
                password: password,
                );
                print(userCredential);
                
                // Navigator.of(context).pushNamedAndRemoveUntil(
                //   '/VerifyEmail/', 
                // (route) => false,
                // );

                } on FirebaseAuthException catch (e) {
                  if (e.code == 'weak-password') {
                    await showErrorDialog(context, 'Weak Password. Needs to be => 6 characters');
                  }
                  else if (e.code == 'email-already-in-use') {
                    await showErrorDialog(context, 'Email is already in use');
                  }
                  else if (e.code == "invalid-email") {
                    await showErrorDialog(context, 'Invalid Email');
                  } else {
                    await showErrorDialog(context, 'Authentication/Internet error');
                  }
                }


                createDemoList();

              final user = FirebaseAuth.instance.currentUser;
              await user?.sendEmailVerification();


          Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login/', 
                  (route) => false
                  );

              showDialog(
              context: context,
              builder: (BuildContext context) {
                return VerifyEmailDialog();
              },
            );
                
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
                'Hello, lets get you signed up!',
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
                onTap: registerUser,
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
                    'Already signed up?',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login/', 
                  (route) => false
                  );
                    },
                    child: Text(
                      'Sign in',
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


