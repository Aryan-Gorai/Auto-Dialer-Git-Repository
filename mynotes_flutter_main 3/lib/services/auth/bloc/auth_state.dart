// State classes emitted by AuthBloc. The UI rebuilds whenever the state changes.
// Each subclass carries the data relevant to its screen (e.g. AuthStateLoggedIn
// holds the user, AuthStateLoggedOut can carry an exception to show an error).

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_application_1/services/auth/auth_user.dart';
import 'package:equatable/equatable.dart';

@immutable
abstract class AuthState {
  final bool isLoading; // true while an async operation is in progress
  final String? loadingText; // optional message shown on the loading overlay

  const AuthState({
    required this.isLoading, 
    this.loadingText = 'Please wait a moment',
  });
}

// Initial state before Firebase has been set up
class AuthStateUninitialized extends AuthState {
  const AuthStateUninitialized({required bool isLoading}) 
    : super (isLoading: isLoading);
}

// User is on the registration screen (may carry an error from a failed attempt)
class AuthStateRegistering extends AuthState {
  final Exception? exception;
  const AuthStateRegistering({
    required this.exception, 
    required isLoading}) : 
  super(isLoading: isLoading);
}

// Successfully authenticated — the app can now show protected screens
class AuthStateLoggedIn extends AuthState {
  final AuthUser user;
  const AuthStateLoggedIn({
    required this.user, 
    required bool isLoading,
    }) : super(isLoading: isLoading);
}

// Email sent but not yet verified — shows the "check your inbox" screen
class AuthStateNeedsVerification extends AuthState {
  const AuthStateNeedsVerification({required bool isLoading})
   : super(isLoading: isLoading,);
}

// Not authenticated. Uses EquatableMixin so BlocBuilder can tell if the
// exception has actually changed (avoids unnecessary rebuilds).
class AuthStateLoggedOut extends AuthState with EquatableMixin {
  final Exception? exception;
  const AuthStateLoggedOut({
    required this.exception,
    required bool isLoading,
    String? loadingText
  }) : super(
    isLoading: isLoading, 
    loadingText: loadingText,
    );

  @override
  List<Object?> get props => [exception, isLoading];
}