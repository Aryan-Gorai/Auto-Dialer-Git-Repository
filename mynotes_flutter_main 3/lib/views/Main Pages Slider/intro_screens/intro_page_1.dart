import 'package:flutter/material.dart';
//import 'package:flutter_application_1/views/list/list_view.dart';

import '../../list/firebase_services.dart';

class RoundedButton extends StatelessWidget {
  
  
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        //_showCreateListDialog(context);
        showListDialogForIntroScreen(context);
      },
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: const Color.fromARGB(255, 0, 0, 0),
      ),
      child: Text('Create a new list', style: TextStyle(fontSize: 18)),
    );
  }

  }


class IntroPage1 extends StatelessWidget {
  
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
              "Welcome, let's get you started by creating a list!",
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: 20),
            RoundedButton(),
          ],
        ),
      ),
    );
  }
}


