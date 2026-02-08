// The BLoC (Business Logic Component) that manages authentication state.
// It listens for AuthEvents dispatched by the UI, talks to the AuthProvider,
// and emits AuthStates that the widget tree reacts to.

import 'package:bloc/bloc.dart';
import 'package:flutter_application_1/services/auth/auth_provider.dart';
import 'package:flutter_application_1/services/auth/bloc/auth_event.dart';
import 'package:flutter_application_1/services/auth/bloc/auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(AuthProvider provider) 
    : super(const AuthStateUninitialized(isLoading: true)) {
    // Handle "resend verification email" — just calls the provider and re-emits current state
    on<AuthEventSendEmailVerification>((event, emit) async {
      await provider.sendEmailVerification();
      emit(state);
    } );

    // Handle registration: create user, then emit logged-in or error state
    on<AuthEventRegister> ((event, emit) async{
      final email = event.email;
      final password = event.password;
      try {
        await provider.createUser(
          email: email, 
          password: password
          );
          emit(AuthStateLoggedIn(
            user: provider.currentUser!,
            isLoading: false,
          ));
      } on Exception catch (e) {
        // Registration failed — stay on the register screen and pass the error
        emit(AuthStateRegistering(
          exception: e, 
          isLoading: false,
          ));
      }
    });

    // App startup: initialise Firebase, then check if someone is already signed in
    on<AuthEventInitialize>((event, emit) async {
      await provider.initialize();
      final user = provider.currentUser;
      if (user == null) {
        emit (
          const AuthStateLoggedOut(
            exception: null, 
            isLoading: false
            ),
        );
      } else {
        emit(AuthStateLoggedIn(
          user: user, 
        isLoading: false,
        ));
      }
    });

    // Log in: show a loading spinner, attempt sign-in, emit result
    on<AuthEventLogIn>((event, emit) async {
      emit(const AuthStateLoggedOut(
        exception: null, 
        isLoading: true,
        loadingText: 'Please wait while I log you in',
        ),
      );
      final email = event.email;
      final password = event.password;
      try {
        final user = await provider.logIn(
          email: email,
          password: password,
        );

        // Briefly emit logged-out (clears loading), then logged-in
        emit(const AuthStateLoggedOut(
            exception: null, 
            isLoading: false
            ),
            );
            emit(AuthStateLoggedIn(
              user: user, 
              isLoading: false,
              ));

        
      } on Exception catch (e) {
        // Login failed — show the error on the login screen
        emit(AuthStateLoggedOut(
          exception: e, 
          isLoading: false,
          ),
          );
      }
    });

    // Log out: sign out and go back to the logged-out screen
    on<AuthEventLogOut>((event, emit) async {
      try {
        await provider.logOut();
        emit(
          const AuthStateLoggedOut(
          exception: null, 
          isLoading: false,
          ),
          );
      } on Exception catch (e) {
        // Even if logout fails we still show logged-out, but with the error
        emit(AuthStateLoggedOut(
          exception: e, 
          isLoading: false,
          ),
          );
      }
    });
  }
}