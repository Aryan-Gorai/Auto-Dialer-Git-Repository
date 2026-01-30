import 'package:flutter/material.dart';
import 'package:cupertino_native/cupertino_native.dart';

import 'package:flutter_application_1/views/list/list_view_visible.dart';
import 'package:flutter_application_1/views/profile/user_profile_editor.dart';
import 'package:flutter_application_1/views/reports/reports_view_clean.dart';
import 'package:flutter_application_1/views/call/call_history_view.dart';
import 'package:flutter_application_1/views/contact_directory/contact_directory_view.dart';



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




  @override
  void initState() {
    super.initState();
    controller = PageController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

// CONTROLLER TO CONTROL WHICH CURRENT PAGE WERE ON




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: buildLiquidGlassTabBar(),
      body: Stack(
        children: [PageView(
          onPageChanged: (pageindex) {
            setState((){
              onLastPage = (pageindex == 4);     // SHOW DONE WHEN ON LAST PAGE (last page index after removal)
            });
          },
          controller: controller,
          physics: const NeverScrollableScrollPhysics(),
        children: [
          //ListScreen(),
          const list_view_visible(),
          const ReportsView(),
          
          const ContactDirectoryView(),
          const CallHistoryView(),
          const UserProfileEditor(),
        ],
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
  Widget buildLiquidGlassTabBar() {
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
    switch (index) {
      case 0:
        controller.jumpToPage(0); // Lists
        break;
      case 1:
        controller.jumpToPage(1); // Reports
        break;
      case 2:
        controller.jumpToPage(2); // Profile
        break;
      case 3:
        controller.jumpToPage(3); // Contact Directory
        break;
      case 4:
        controller.jumpToPage(4); // History
        break;
    }
  }
}
