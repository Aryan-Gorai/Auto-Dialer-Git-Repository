// Main container screen after login. Uses a PageView with a bottom tab bar
// to switch between the app's primary sections. The visible tabs depend on
// the user's role: team_members see Lists, Reports, Contacts, History, Profile;
// team_owners see Reports (with member selector), Team Management, Profile.
// If no role is stored yet, a picker dialog is shown on first launch.

import 'package:flutter/material.dart';
import 'package:cupertino_native/cupertino_native.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

import 'package:flutter_application_1/views/list/list_view_visible.dart';
import 'package:flutter_application_1/views/profile/user_profile_editor.dart';
import 'package:flutter_application_1/views/reports/reports_view_clean.dart';
import 'package:flutter_application_1/views/reports/team_reports_view.dart';
import 'package:flutter_application_1/views/call/call_history_view.dart';
import 'package:flutter_application_1/views/contact_directory/contact_directory_view.dart';
import 'package:flutter_application_1/views/team/team_management_view.dart';



class sliderScreen extends StatefulWidget {
  const sliderScreen({super.key});

  @override
  State<sliderScreen> createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<sliderScreen> {
  // Move controller inside the State class to fix hot reload issues
  late PageController controller;
  bool onLastPage = false;

// STUFF FOR BOTTOMNAVIGATIONBAR (now using CNTabBar)
  int _tabIndex = 0; // Track the current tab index

  // Role-based state
  String? _userRole; // 'team_member', 'team_owner', or null (needs selection)
  bool _roleLoading = true;
  String _userId = '';


  @override
  void initState() {
    super.initState();
    controller = PageController();
    _loadUserRole();
  }

  // Reads the user's role from Firestore on startup.
  // If the profile doc doesn't exist or has no role, shows a picker dialog.
  Future<void> _loadUserRole() async {
    final user = fb_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _roleLoading = false);
      return;
    }
    _userId = user.uid;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(_userId)
          .get();

      String? role;
      if (doc.exists) {
        role = doc.data()?['role'] as String?;
      }

      if (mounted) {
        setState(() {
          _userRole = role;
          _roleLoading = false;
        });

        // If role is null, show role picker for existing users
        if (role == null) {
          _showRolePickerDialog();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _roleLoading = false);
    }
  }

  void _showRolePickerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String selectedRole = 'team_member';
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Choose Your Role'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Welcome! Please select your role to continue:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  _buildRoleOption(
                    ctx,
                    'Team Member',
                    'Make calls & join a team',
                    Icons.person,
                    'team_member',
                    selectedRole,
                    (val) => setDialogState(() => selectedRole = val),
                  ),
                  const SizedBox(height: 10),
                  _buildRoleOption(
                    ctx,
                    'Team Owner',
                    'Manage a team & view their reports',
                    Icons.admin_panel_settings,
                    'team_owner',
                    selectedRole,
                    (val) => setDialogState(() => selectedRole = val),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _saveRole(selectedRole);
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRoleOption(
    BuildContext ctx,
    String title,
    String subtitle,
    IconData icon,
    String value,
    String groupValue,
    Function(String) onChanged,
  ) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.blue : Colors.grey, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.blue : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  // Writes the selected role back to Firestore and refreshes the UI
  Future<void> _saveRole(String role) async {
    setState(() => _roleLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(_userId)
          .set({
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _userRole = role;
          _roleLoading = false;
          _tabIndex = 0;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _roleLoading = false);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }


  // Returns a different set of pages depending on the user's role
  List<Widget> get _pages {
    if (_userRole == 'team_owner') {
      return const [
        TeamReportsView(),      // index 0: Reports with member selector
        TeamManagementView(),   // index 1: Team management
        UserProfileEditor(),    // index 2: Profile
      ];
    }
    // Default: team_member or unknown
    return const [
      list_view_visible(),
      ReportsView(),
      ContactDirectoryView(),
      CallHistoryView(),
      UserProfileEditor(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_roleLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pages = _pages;

    return Scaffold(
      bottomNavigationBar: buildLiquidGlassTabBar(),
      body: Stack(
        children: [PageView(
          onPageChanged: (pageindex) {
            setState((){
              onLastPage = (pageindex == pages.length - 1);
            });
          },
          controller: controller,
          physics: const NeverScrollableScrollPhysics(),
          children: pages,
      ),


      Container(
        alignment: Alignment(0,0.75),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [

        
              
          ],
        ))
      ],
      )
    );
  }


  // Liquid Glass Tab Bar using Cupertino Native
  // Builds the iOS-style liquid glass tab bar at the bottom.
  // Different tabs shown for team_owner vs team_member roles.
  Widget buildLiquidGlassTabBar() {
    if (_userRole == 'team_owner') {
      return CNTabBar(
        items: const [
          CNTabBarItem(
            label: 'Reports',
            icon: CNSymbol('chart.bar.fill', size: 24),
          ),
          CNTabBarItem(
            label: 'Team',
            icon: CNSymbol('person.3.fill', size: 24),
          ),
          CNTabBarItem(
            label: 'Profile',
            icon: CNSymbol('person.crop.circle', size: 24),
          ),
        ],
        currentIndex: _tabIndex,
        onTap: (index) {
          setState(() {
            _tabIndex = index;
            controller.jumpToPage(index);
          });
        },
      );
    }

    // Default: team_member tabs
    return CNTabBar(
      items: const [
        CNTabBarItem(
          label: 'Lists', 
          icon: CNSymbol('list.bullet', size: 24)
        ),
        CNTabBarItem(
          label: 'Reports', 
          icon: CNSymbol('chart.bar.fill', size: 24)
        ),

        CNTabBarItem(
          label: 'Contacts', 
          icon: CNSymbol('person.2.fill', size: 24)
        ),
        CNTabBarItem(
          label: 'History', 
          icon: CNSymbol('clock.fill', size: 24)
        ),
        CNTabBarItem(
          label: 'Profile', 
          icon: CNSymbol('person.crop.circle', size: 24)
        ),
      ],
      currentIndex: _tabIndex,
      onTap: (index) {
        setState(() {
          _tabIndex = index;
          navigateToPage(index);
        });
      },
    );
  }

  void navigateToPage(int index) {
    controller.jumpToPage(index);
  }
}
