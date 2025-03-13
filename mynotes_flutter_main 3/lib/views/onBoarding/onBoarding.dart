import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/constants/routes.dart';
import 'package:flutter_application_1/views/dialer/dialer.dart';

import 'package:flutter_application_1/views/onBoarding/intro_screens/intro_page_1.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'intro_screens/intro_page_2.dart';
import 'intro_screens/intro_page_3.dart';


class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({super.key});

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();
}

  PageController controller = PageController();

bool onLastPage = false;

class _OnBoardingScreenState extends State<OnBoardingScreen> {



// CONTROLLER TO CONTROL WHICH CURRENT PAGE WERE ON




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: Stack(
        children: [PageView(
          onPageChanged: (pageindex) {
            setState((){
              onLastPage = (pageindex == 2);     // SHOW DONE WHEN ON LAST PAGE
            });
          },
          controller: controller,
        children: [
          IntroPage1(),
          IntroPage2(),
          IntroPage3(),
        ],
      ),


      Container(
        alignment: Alignment(0,0.75),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [

            GestureDetector(
              onTap:(){
                controller.jumpToPage(2);

              },
              child: Text("Skip")
              ),

            SmoothPageIndicator(controller: controller, count: 3),


            onLastPage
            ?  GestureDetector(
              onTap:(){
                    
            //  Navigator.of(context).push(
            //                 MaterialPageRoute(
            //                   builder: (context) => DialerView(),
            // ));
          Navigator.of(context).pushNamedAndRemoveUntil( sliderScreenRoute, (route) => false);
                  
             
             
                // controller.nextPage(
                //   duration: Duration(milliseconds: 500), 
                //   curve: Curves.easeIn);
              },
              child: Text("Done")):
               GestureDetector(
              onTap:(){         // CODE TO STOP FROM GOING TO NEXT PAGE
            //  Navigator.of(context).push(
            //                 MaterialPageRoute(
            //                   builder: (context) => ListScreen(),
            //  ));

                 controller.nextPage(
                  duration: Duration(milliseconds: 500), 
                  curve: Curves.easeIn);

                  

              },
              child: Text("Next")
              
              ),
              
          ],
        ))
      ],
      )
    );
  }







  
}