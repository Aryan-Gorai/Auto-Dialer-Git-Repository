// Lightweight, immutable model representing the currently signed-in user.
// Keeps only the fields we actually need (id, email, verification status)
// so the rest of the app never depends directly on Firebase's User class.

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/foundation.dart';

@immutable
class AuthUser {
  final String id;
  final String email;
  final bool isEmailVerified;
  const AuthUser({
    required this.id,
    required this.email,
    required this.isEmailVerified,
  });

  // Factory that pulls the bits we care about out of a Firebase User object
  factory AuthUser.fromFirebase(User user) => AuthUser(
    id: user.uid,
        email: user.email!,
        isEmailVerified: user.emailVerified,
      );
}


