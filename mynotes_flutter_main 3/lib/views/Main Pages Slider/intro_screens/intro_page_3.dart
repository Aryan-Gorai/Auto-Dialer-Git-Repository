// Third intro page — confirms the list was created and tells the user
// they'll be taken to the dialer page next.

import 'package:flutter/material.dart';

import '../../list/firebase_services.dart';



class IntroPage3 extends StatefulWidget {
  @override
  State<IntroPage3> createState() => _IntroPage3State();
}

class _IntroPage3State extends State<IntroPage3> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color.fromARGB(255, 140, 143, 219),
      alignment: Alignment(0, -0.80),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Nice!, youve created the list $selectedList and I'll take you to the dialer page. ",
              
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: 20),
            
          ],
        ),
      ),
    );
  }
}


