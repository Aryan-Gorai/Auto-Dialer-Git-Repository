import 'package:flutter/material.dart';
import 'package:fluttercontactpicker/fluttercontactpicker.dart';
//import 'package:flutter_application_1/views/list/list_view.dart';

import '../../list/firebase_services.dart';

class RoundedButton extends StatefulWidget {
  
  
  @override
  State<RoundedButton> createState() => _RoundedButtonState();
}

class _RoundedButtonState extends State<RoundedButton> {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
                bool permission = await FlutterContactPicker.requestPermission();


                 if (permission) {
                   if (await FlutterContactPicker.hasPermission()) {
                     phoneContact = await FlutterContactPicker.pickPhoneContact();


                     if (phoneContact != null) {
                       if (phoneContact!.fullName != null && phoneContact!.fullName!.isNotEmpty) {
                         setState(() {
                           kPickedName = phoneContact!.fullName.toString();
                         });
                       }
                       if (phoneContact!.phoneNumber != null &&
                           phoneContact!.phoneNumber!.number!.isNotEmpty) {
                         setState(() {
                           kPickedNumber = phoneContact!.phoneNumber!.number.toString();
                         });
                       }
                     }
                   }
                 }

                  addNewContactDataToList(selectedList);
                 fetchDocumentsInOrder();
      },
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Color.fromARGB(255, 0, 0, 0),
      ),
      child: Text('Select Contact(s)', style: TextStyle(fontSize: 18)),
    );
  }
}


class IntroPage2 extends StatelessWidget {
  
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color.fromARGB(255, 150, 112, 214),
      alignment: Alignment(0, -0.80),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Great, You're list is $selectedList!",
              textAlign: TextAlign.center,
            ),
            Text(
              "Now upload at least 3 contacts!",
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


