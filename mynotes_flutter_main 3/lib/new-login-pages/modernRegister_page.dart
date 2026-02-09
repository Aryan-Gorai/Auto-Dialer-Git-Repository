// Registration screen where new users create an account.
// After sign-up, a Firestore user_profiles document is created with the
// chosen role (team_member or team_owner). Team members also get a demo
// list created for them automatically.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:flutter_application_1/theme/components/app_components.dart';

import 'package:flutter_application_1/utilities/dialogs/error_dialog.dart';
import 'package:flutter_application_1/views/list/list_view.dart';



class RegisterScreen1 extends StatefulWidget {
  const RegisterScreen1({super.key});

  @override
  State<RegisterScreen1> createState() => _LoginPageState();
}

class _LoginPageState extends State<RegisterScreen1> {
 
  // text editing controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // Role selection: 'team_member' or 'team_owner'
  String _selectedRole = 'team_member';
  bool _isLoading = false;

  // Creates a Firebase account, writes a Firestore profile doc with the
  // selected role, creates a demo list for team members, then redirects to login.
  Future<void> registerUser() async {
    final email = emailController.text;
    final password = passwordController.text;

    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email, 
        password: password,
      );
      print(userCredential);

    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        await showErrorDialog(context, 'Weak Password. Needs to be => 6 characters');
      }
      else if (e.code == 'email-already-in-use') {
        await showErrorDialog(context, 'Email is already in use');
      }
      else if (e.code == "invalid-email") {
        await showErrorDialog(context, 'Invalid Email');
      } else {
        await showErrorDialog(context, 'Authentication/Internet error');
      }
    }

    // Create user profile in Firestore with role
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(user.uid)
          .set({
        'user_id': user.uid,
        'email': user.email ?? '',
        'name': '',
        'phone': '',
        'about': '',
        'photoUrl': '',
        'role': _selectedRole,
        'team_id': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Only create demo list for team members (owners are manager-only)
    if (_selectedRole == 'team_member') {
      createDemoList();
    }

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login/', 
        (route) => false,
      );
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
                        Icons.person_add_alt_1_rounded,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Title
                    const Text(
                      'Create your account',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppDesignTokens.neutral900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Get started with Auto Dialer',
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
                            hintText: 'Create a password',
                            obscureText: true,
                            prefixIcon: Icons.lock_outline,
                            textInputAction: TextInputAction.done,
                          ),

                          const SizedBox(height: 22),

                          // Role selection
                          const Text(
                            'I am a:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppDesignTokens.neutral700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: AppDesignTokens.neutral100,
                              borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                _buildRoleOption('team_member', 'Team Member', Icons.people_outline),
                                const SizedBox(width: 4),
                                _buildRoleOption('team_owner', 'Team Owner', Icons.admin_panel_settings_outlined),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedRole == 'team_member'
                                ? 'You can make calls and join a team.'
                                : 'You can manage a team and view their reports.',
                            style: const TextStyle(
                              color: AppDesignTokens.neutral500,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Register button
                          AppPrimaryButton(
                            label: 'Create Account',
                            onPressed: registerUser,
                            expanded: true,
                            isLoading: _isLoading,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Sign in link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account?',
                          style: TextStyle(
                            color: AppDesignTokens.neutral600,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/login/', 
                              (route) => false,
                            );
                          },
                          child: const Text(
                            'Sign in',
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

  Widget _buildRoleOption(String role, String label, IconData icon) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppDesignTokens.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
            boxShadow: isSelected ? AppDesignTokens.softShadow : [],
            border: isSelected 
                ? Border.all(color: AppDesignTokens.primary.withOpacity(0.3))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppDesignTokens.primary : AppDesignTokens.neutral500,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppDesignTokens.primary : AppDesignTokens.neutral600,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
