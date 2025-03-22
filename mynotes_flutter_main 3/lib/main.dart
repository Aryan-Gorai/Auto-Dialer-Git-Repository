
import 'package:flutter/material.dart';
import 'package:flutter_application_1/constants/routes.dart';

import 'package:flutter_application_1/home_page.dart';
import 'package:flutter_application_1/new-login-pages/modernLogin_page.dart';
import 'package:flutter_application_1/new-login-pages/modernRegister_page.dart';


import 'package:flutter_application_1/services/auth/bloc/auth_bloc.dart';

import 'package:flutter_application_1/services/auth/firebase_auth_provider.dart';
import 'package:flutter_application_1/views/Main%20Pages%20Slider/sliderScreen.dart';
import 'package:flutter_application_1/views/call/contact_upload.dart';
import 'package:flutter_application_1/views/list/firebase_services.dart';

import 'package:flutter_application_1/views/list/list_view.dart';
import 'package:flutter_application_1/views/list/list_view_visible.dart';



import 'package:flutter_application_1/views/notes/create_update_note_view.dart';

import 'package:flutter_bloc/flutter_bloc.dart';



void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BlocProvider<AuthBloc>(
        create: (context) => AuthBloc(FirebaseAuthProvider()),
        child:  HomePage(),

        // list_view_visible(),

        //child: RegisterScreen1(),
        //child: LoginScreen1(),
      ),
      routes: {
        //registerRoute: (context) => const RegisterView(),
        createOrUpdateNoteRoute: (context) => const CreateUpdateNoteView(),
        flutterContactsExampleRoute: (context) =>  CallView(), 
        //ListRoute: (context) => ListScreen(),
       // ListRoute1: (context) => ListScreen1(),
        //ListRoute: (context) => LoginPage(),
        //  '/VerifyEmail/' : (context) => VerifyEmailView2(),
        '/login/' : (context) => const LoginScreen1(),
        '/register/' : (context) => const RegisterScreen1(),
        sliderScreenRoute: (context) => sliderScreen(),
      
      //'/list_view/': (context) => ListScreen(),
      '/list_view/': (context) => sliderScreen(),

      },
    ),
  );
}

// class HomePage extends StatelessWidget {
//   const HomePage({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     context.read<AuthBloc>().add(const AuthEventInitialize());
//     return BlocConsumer<AuthBloc, AuthState>(
//       listener: (context, state) {
//         if (state.isLoading) {
//           LoadingScreen().show(
//             context: context, 
//             text: state.loadingText ?? 'Please wait a moment',
//             );
//         } else {
//           LoadingScreen().hide();
//         }
//       },
//       builder: (context, state) {
//         if (state is AuthStateLoggedIn) {
//           return const NotesView();
//         } else if (state is AuthStateNeedsVerification) {
//           return const VerifyEmailView();
//         } else if (state is AuthStateLoggedOut) {
//           return const LoginView();
//         } else if(state is AuthStateRegistering) {
//           return const RegisterView();
//         } else {
//           return const Scaffold(
//             body: CircularProgressIndicator(),
//           );
//         }
//       },
//     );
//   }
// }