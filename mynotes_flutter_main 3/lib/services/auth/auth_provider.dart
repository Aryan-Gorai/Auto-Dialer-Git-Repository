// Abstract interface that defines every auth operation the app needs.
// FirebaseAuthProvider is the concrete implementation, but having this
// abstraction means we could swap to a different backend without
// touching the rest of the code.

import 'package:flutter_application_1/services/auth/auth_user.dart';

abstract class AuthProvider {
  Future<void> initialize(); // set up whatever backend we're using
  AuthUser? get currentUser; // null if nobody is signed in
  Future<AuthUser> logIn({
    required String email,
    required String password,
});
  Future<AuthUser> createUser({
    required String email,
    required String password,
  });
  Future<void> logOut();
  Future<void> sendEmailVerification();
}