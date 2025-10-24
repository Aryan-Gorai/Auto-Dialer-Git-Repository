import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/views/dialer/dialer.dart';
import 'package:flutter_application_1/views/list/firebase_services.dart';

// import 'package:flutter_application_1/views/list/list_view.dart';
import 'package:flutter_application_1/views/list/list_view_visible.dart';
import 'package:flutter_application_1/views/profile/user_profile_editor.dart';
import 'package:flutter_application_1/views/reports/reports_view_clean.dart';
import 'package:flutter_application_1/views/call/call_history_view.dart';



class sliderScreen extends StatefulWidget {
  const sliderScreen({super.key});

  @override
  State<sliderScreen> createState() => _OnBoardingScreenState();
}

  PageController controller = PageController();

bool onLastPage = false;

class _OnBoardingScreenState extends State<sliderScreen> {

// STUFF FOR BOTTOMNAVIGATIONBAR


// int _page = 0; // no longer used





 // Define _page variable
  GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey(); // Define _bottomNavigationKey variable


// STUFF FOR BOTTOMNAVIGATIONBAR






// CONTROLLER TO CONTROL WHICH CURRENT PAGE WERE ON




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: buildCurvedNavigationBar(),
      body: Stack(
        children: [PageView(
          onPageChanged: (pageindex) {
            setState((){
              onLastPage = (pageindex == 3);     // SHOW DONE WHEN ON LAST PAGE (last page index after removal)
            });
          },
          controller: controller,
          physics: NeverScrollableScrollPhysics(),
        children: [
          //ListScreen(),
          list_view_visible(),
          ReportsView(),
          UserProfileEditor(),
          CallHistoryView(),
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





  Widget buildCurvedNavigationBar() {
    return CurvedNavigationBar(










      key: _bottomNavigationKey,
      index: 0,
      height: 60.0,
      items: <Widget>[
        Icon(Icons.list, size: 30),
        Icon(Icons.bar_chart, size: 30),
        Icon(Icons.perm_identity, size: 30),
        Icon(Icons.history, size: 30),
      ],
      color: Colors.white,
      buttonBackgroundColor: Colors.white,
      backgroundColor: Color.fromRGBO(248, 225, 209, 1),
      animationCurve: Curves.easeInOut,
      animationDuration: Duration(milliseconds: 600),
      onTap: (index) {
        setState(() {
          navigateToPage(index);
          //pageNavigator(index);
        });
      },
      letIndexChange: (index) => true,
    );





  }


Widget pageNavigator(int index) {
  if (index == 2) {
    return DialerContactsView(listName: selectedList,);
  } else {
    // Return something else or null if index is not equal to 2
    return Container(); // You can replace this with the appropriate widget
  }
}


  void navigateToPage(int index) {
    switch (index) {
      case 0:
        // Navigate to the first page
        //Navigator.pushNamed(context, ListRoute1);
        controller.jumpToPage(0);

        break;
      case 1:
        controller.jumpToPage(1); // Reports
        break;
      case 2:
        controller.jumpToPage(2); // Profile
        break;
      case 3:
        controller.jumpToPage(3); // History
        break;
      // Add cases for other pages as needed
    }
  }











  
}
