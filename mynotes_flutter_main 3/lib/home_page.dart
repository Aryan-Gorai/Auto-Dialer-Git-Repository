import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:flutter_application_1/new-login-pages/modernLogin_page.dart';


import 'package:flutter_application_1/views/Main%20Pages%20Slider/sliderScreen.dart';






class HomePage extends StatelessWidget {
  const HomePage({super.key});



  @override
  Widget build(BuildContext context) {
    // Firebase is already initialized in main.dart
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
  }}