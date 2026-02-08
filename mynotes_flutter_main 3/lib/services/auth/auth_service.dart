// Thin wrapper around whatever AuthProvider we're using (currently Firebase).
// Every call just delegates to the underlying provider — this exists so the
// rest of the app only talks to AuthService and never directly to Firebase.

import 'package:flutter_application_1/services/auth/auth_provider.dart';
import 'package:flutter_application_1/services/auth/auth_user.dart';
import 'firebase_auth_provider.dart';


class AuthService implements AuthProvider {
  final AuthProvider provider;
  const AuthService(this.provider);

  // Convenience factory: gives you an AuthService already wired to Firebase
  factory AuthService.firebase() => AuthService(FirebaseAuthProvider());

  @override
  Future<AuthUser> createUser({
    required String email,
    required String password,
  }) =>
      provider.createUser(
        email: email,
        password: password,
      );

  @override
  AuthUser? get currentUser => provider.currentUser;

  @override
  Future<AuthUser> logIn({
    required String email,
    required String password,
  }) =>
      provider.logIn(
        email: email,
        password: password,
      );

  @override
  Future<void> logOut() => provider.logOut();

  @override
  Future<void> sendEmailVerification() => provider.sendEmailVerification();

  @override
  Future<void> initialize() => provider.initialize();
}
