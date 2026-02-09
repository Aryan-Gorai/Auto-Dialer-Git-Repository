// Modern login screen using Firebase Auth directly (not via the BLoC).
// Shows email + password fields, a sign-in button, and a link to the
// register page. On success, navigates straight to the list view.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/constants/routes.dart';
import 'package:flutter_application_1/theme/components/app_components.dart';

import 'package:flutter_application_1/utilities/dialogs/error_dialog.dart';


class LoginScreen1 extends StatefulWidget {
  const LoginScreen1({super.key});

  @override
  State<LoginScreen1> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginScreen1> {
 
  // text editing controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isLoading = false;

  // Attempts Firebase sign-in and navigates to the list page on success.
  // Catches specific Firebase error codes to show helpful messages.
  Future<void> signUserIn() async {               
    final email = emailController.text;
    final password = passwordController.text;

    setState(() => _isLoading = true);

    try {
      print("Attempting to sign in user: $email");

      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email, 
        password: password,
      );

      print("User Credential: $userCredential");
      print("User: ${userCredential.user}");

      if (!mounted) return;

      if (FirebaseAuth.instance.currentUser != null) {
        Navigator.of(context).pushNamedAndRemoveUntil(ListRoute, (route) => false);
      }

    } on FirebaseAuthException catch (e) {
      print("FirebaseAuthException: ${e.code}");
      
      if (e.code == 'user-not-found') {
        await showErrorDialog(context, 'User not found');
      } else if (e.code == 'wrong-password'){
        await showErrorDialog(context, 'Wrong Username or Password');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),

                    // Logo icon
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: AppDesignTokens.primaryGradient,
                        borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg),
                        boxShadow: AppDesignTokens.coloredShadow,
                      ),
                      child: const Icon(
                        Icons.phone_in_talk_rounded,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Title
                    const Text(
                      'Welcome back',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppDesignTokens.neutral900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in to continue',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppDesignTokens.neutral500,
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Form card
                    AppCard(
                      padding: const EdgeInsets.all(24),
                      shadow: AppDesignTokens.elevatedShadow,
                      borderRadius: AppDesignTokens.radiusLg,
                      borderColor: AppDesignTokens.neutral100,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Email field
                          AppTextField(
                            controller: emailController,
                            labelText: 'Email',
                            hintText: 'Enter your email',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                          ),

                          const SizedBox(height: 18),

                          // Password field
                          AppTextField(
                            controller: passwordController,
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            obscureText: true,
                            prefixIcon: Icons.lock_outline,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => signUserIn(),
                          ),

                          const SizedBox(height: 8),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 32),
                              ),
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppDesignTokens.primary,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Sign in button
                          AppPrimaryButton(
                            label: 'Sign In',
                            onPressed: signUserIn,
                            expanded: true,
                            isLoading: _isLoading,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Register link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'New here?',
                          style: TextStyle(
                            color: AppDesignTokens.neutral600,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/register/', 
                              (route) => false,
                            );
                          },
                          child: const Text(
                            'Create an account',
                            style: TextStyle(
                              color: AppDesignTokens.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
