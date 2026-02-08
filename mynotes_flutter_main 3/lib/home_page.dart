// Home page widget that checks Firebase auth state and routes accordingly.
// If the user is logged in, they see the main slider screen; otherwise the login page.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/firebase_options.dart';

import 'package:flutter_application_1/new-login-pages/modernLogin_page.dart';


import 'package:flutter_application_1/views/Main%20Pages%20Slider/sliderScreen.dart';






class HomePage extends StatelessWidget {
  const HomePage({super.key});



  @override
  Widget build(BuildContext context) {
    // FutureBuilder waits for Firebase to initialise before rendering anything
    return  FutureBuilder(
      
      future:Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ),

    builder: (context, snapshot) {
      switch (snapshot.connectionState) {

      // Once Firebase is ready, check if a user is currently signed in
      case ConnectionState.done:
      final user = FirebaseAuth.instance.currentUser;
    
      if (user != null) {
          return sliderScreen(); // user is logged in — show the main app
      } else {
        return const LoginScreen1(); // no user — show the login page
      }

       // return ListScreen();

       
      
      default: 
        return const CircularProgressIndicator();
      

      }
      


        },
       
      );
  }}