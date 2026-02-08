// Immutable event classes that the UI dispatches to the AuthBloc.
// Each event represents a user action: initialise the app, log in,
// register, log out, verify email, etc.

import 'package:flutter/foundation.dart' show immutable;

@immutable
abstract class AuthEvent{
    const AuthEvent();
}

// Fired once at app startup to kick off Firebase init
class AuthEventInitialize extends AuthEvent {
    const AuthEventInitialize();
}

// User tapped "resend verification email"
class AuthEventSendEmailVerification extends AuthEvent {
  const AuthEventSendEmailVerification();
}

// User submitted the login form with email + password
class AuthEventLogIn extends AuthEvent{
    final String email;
    final String password;

    const AuthEventLogIn(this.email, this.password);
}

// User submitted the registration form
class AuthEventRegister extends AuthEvent{
  final String email;
  final String password;
  const AuthEventRegister(this.email, this.password);
}

// User tapped "Don't have an account? Register here"
class AuthEventShouldRegister extends AuthEvent {
  const AuthEventShouldRegister();
}

// User tapped the logout button
class AuthEventLogOut extends AuthEvent {
    const AuthEventLogOut();
}

