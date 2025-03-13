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
    return  FutureBuilder(
      
      future:Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ),

    builder: (context, snapshot) {
      switch (snapshot.connectionState) {

      case ConnectionState.done:
      final user = FirebaseAuth.instance.currentUser;
    
      if (user != null) {
        if (user.emailVerified) {
          //return ListScreen();
          return sliderScreen();
        } else {
          return LoginScreen1();
          
          }
      } else {
        return const LoginScreen1();
      }

       // return ListScreen();

       
      
      default: 
        return const CircularProgressIndicator();
      

      }
      


        },
       
      );
  }}