// Registration screen where new users create an account.
// After sign-up, a Firestore user_profiles document is created with the
// chosen role (team_member or team_owner). Team members also get a demo
// list created for them automatically.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:flutter_application_1/new-login-pages/my_button_register.dart';
import 'package:flutter_application_1/new-login-pages/my_textfield.dart';


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

  // Role selection: 'team_member' or 'team_owner'
  String _selectedRole = 'team_member';









  // Creates a Firebase account, writes a Firestore profile doc with the
  // selected role, creates a demo list for team members, then redirects to login.
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


                // Create user profile in Firestore with role
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseFirestore.instance
                      .collection('user_profiles')
                      .doc(user.uid)
                      .set({
                    'user_id': user.uid,
                    'email': user.email ?? '',
                    'name': '',
                    'phone': '',
                    'about': '',
                    'photoUrl': '',
                    'role': _selectedRole,
                    'team_id': null,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                }

                // Only create demo list for team members (owners are manager-only)
                if (_selectedRole == 'team_member') {
                  createDemoList();
                }

          Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login/', 
                  (route) => false
                  );
                
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
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

              const SizedBox(height: 20),

              // Role selection toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'I am a:',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedRole = 'team_member');
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedRole == 'team_member'
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _selectedRole == 'team_member'
                                      ? [
                                          BoxShadow(
                                            color: Colors.grey.withOpacity(0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Center(
                                  child: Text(
                                    'Team Member',
                                    style: TextStyle(
                                      color: _selectedRole == 'team_member'
                                          ? Colors.blue
                                          : Colors.grey[600],
                                      fontWeight: _selectedRole == 'team_member'
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedRole = 'team_owner');
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedRole == 'team_owner'
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _selectedRole == 'team_owner'
                                      ? [
                                          BoxShadow(
                                            color: Colors.grey.withOpacity(0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Center(
                                  child: Text(
                                    'Team Owner',
                                    style: TextStyle(
                                      color: _selectedRole == 'team_owner'
                                          ? Colors.blue
                                          : Colors.grey[600],
                                      fontWeight: _selectedRole == 'team_owner'
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedRole == 'team_member'
                          ? 'You can make calls and join a team.'
                          : 'You can manage a team and view their reports.',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
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
      ),
    );
  }
}
