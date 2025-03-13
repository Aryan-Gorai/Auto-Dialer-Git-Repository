import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/views/dialer/dialer.dart';
import 'package:flutter_application_1/views/list/firebase_services.dart';

import 'package:flutter_application_1/views/list/list_view.dart';
import 'package:flutter_application_1/views/reports/reports_view.dart';



class sliderScreen extends StatefulWidget {
  const sliderScreen({super.key});

  @override
  State<sliderScreen> createState() => _OnBoardingScreenState();
}

  PageController controller = PageController();

bool onLastPage = false;

class _OnBoardingScreenState extends State<sliderScreen> {

// STUFF FOR BOTTOMNAVIGATIONBAR


int _page = 0;





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
              onLastPage = (pageindex == 2);     // SHOW DONE WHEN ON LAST PAGE
            });
          },
          controller: controller,
        children: [
          ListScreen(),
          DialerContactsView(listName: selectedList),
          ReportsView(),
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
        Icon(Icons.call, size: 30),
        Icon(Icons.bar_chart, size: 30),
        // Icon(Icons.call_split, size: 30),
        Icon(Icons.perm_identity, size: 30),
      ],
      color: Colors.white,
      buttonBackgroundColor: Colors.white,
      backgroundColor: Color.fromRGBO(248, 225, 209, 1),
      animationCurve: Curves.easeInOut,
      animationDuration: Duration(milliseconds: 600),
      onTap: (index) {
        setState(() {
          _page = index;
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
        // Navigate to the second page
        // Navigator.pushReplacementNamed(context, '/second_page');
        //Navigator.of(context).push(MaterialPageRoute(builder: (context) => const DialerViewCopy()));
        //return DialerViewCopy();
        controller.jumpToPage(1);

        break;   

      case 2:
      controller.jumpToPage(2);


        break;
      // Add cases for other pages as needed
    }
  }











  
}