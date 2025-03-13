


import 'package:bloc/bloc.dart';
//import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

//import 'package:flutter_application_1/curved_nagivation_bar.dart';

import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:flutter_application_1/utilities/dialogs/delete_options_dialog.dart';
import 'package:flutter_application_1/utilities/dialogs/error_dialog.dart';
import 'package:flutter_application_1/utilities/dialogs/logout_dialog.dart';
import 'package:flutter_application_1/utilities/dialogs/welcome_dialog.dart';
import 'package:flutter_application_1/views/list/firebase_services.dart';
import 'package:flutter_application_1/views/list/list_view_visible.dart';
import 'package:flutter_application_1/views/onBoarding/onBoarding.dart';
import 'package:fluttercontactpicker/fluttercontactpicker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
// import  'package:flutter_application_1/views/list/firebase_services.dart';

import '../../enums/menu_action.dart';

void main() async {
 WidgetsFlutterBinding.ensureInitialized();
 await Firebase.initializeApp(); // Initialize Firebase
 

 runApp(const MyApp());


}














// Functions for the card code...

class ImgSample {
  static String get(String imageName) {
    return "asses/image/$imageName";
  }
}










class MyStringsSample {
  static const String card_text =
      "This is a sample card description. You can replace it with your own text.";
}

class MyColorsSample {
  static const Color accent = Colors.blue; // Replace with your desired color
}




// Functions for the card code...

 Future<void>  DeleteAllListsButtonFunction() async {

              FirebaseFirestore firestore = FirebaseFirestore.instance;
              CollectionReference listsRef = firestore.collection('lists_collection');

              QuerySnapshot querySnapshot = await listsRef.get();

              for (QueryDocumentSnapshot docSnapshot in querySnapshot.docs) {
                Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>; // Cast to Map
                // Check if the 'user_id' field matches the userId variable
                if (data['user_id'] == userId) {
                  await docSnapshot.reference.delete();
                }
              }

              listName = 'List 1';
              index = 0;
              totalDocuments = 0;
              selectedList = listName;
              Map<String, dynamic> newListData = {
                'list_name': listName,
                'user_id': userId,
                'current_index': index,
                'total_documents': totalDocuments,
              };

              // Add the new document with an auto-generated ID
              await listsRef.add(newListData);

              fetchDataFromFirestore();
              
            // fetchContactsAsArray(selectedList);




 }



 Future<void>  DeleteAllContactsButtonFunction() async {

        FirebaseFirestore firestore = FirebaseFirestore.instance;
              CollectionReference listsRef = firestore.collection('lists');
              
              QuerySnapshot querySnapshot = await listsRef.get();
              
              for (QueryDocumentSnapshot docSnapshot in querySnapshot.docs) {
                Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>; // Cast to Map
                // Check if the 'user_id' field matches the userId variable
                if (data['user_id'] == userId) {
                  await docSnapshot.reference.delete();
                }
              }


            fetchDataFromFirestore();


 }


Future<void> DeleteAllContactsFromListButtonFunction() async {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  CollectionReference listsRef = firestore.collection('lists');

  QuerySnapshot querySnapshot = await listsRef.get();

  for (QueryDocumentSnapshot docSnapshot in querySnapshot.docs) {
    Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;

    // Check if both conditions are met before deleting
    if (data['user_id'] == userId && data['list_name'] == selectedList) {
      await docSnapshot.reference.delete();
    }
  }

  fetchDataFromFirestore();
}

// Functions for the card code...
// Functions for the card code...






 String listContactsJoinedforDialerView = ''; // This variable is used to transfer information between list_view and dialerview. This will hold the names of the contacts in the list.








Future<void> createDemoList() async {
  try {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    CollectionReference listsRef = firestore.collection('lists_collection');

    String listName = 'List 1';
    int index = 0;
    int totalDocuments = 0;
    String selectedList = listName;

    Map<String, dynamic> newListData = {
      'list_name': listName,
      'user_id': userId,
      'current_index': index,
      'total_documents': totalDocuments,
    };

    // Add the new document with an auto-generated ID
    await listsRef.add(newListData);

    // You can perform any additional actions after creating the list here.

  } catch (error) {
    // Handle errors here
    print('Error: $error');
  }
}



// Define the myTiles variable to hold the document data























// CODE FOR best fist DROPDOWN
 class ListBloc extends Cubit<List<String>> {
  ListBloc() : super([]);
  Future<void> fetchDocuments() async {
    QuerySnapshot querySnapshot =
        await FirebaseFirestore.instance.collection('lists_collection').get();
    
    List<String> newItems = [];
    for (QueryDocumentSnapshot document in querySnapshot.docs) {
      newItems.add(document.get('document_field')); // Replace with your field name
    }
    emit(newItems);



  }
}













// CODE FOR DROPDOWN
List<String> list = <String>["Temp"];  // Initialises with a demo contact so that there is no red screen. 
String dropdownValue = list.first;
String listName = '';
// CODE FOR DROPDOWN



class MyApp extends StatelessWidget {
 const MyApp({Key? key}) : super(key: key);


 @override
 Widget build(BuildContext context) {
   return const MaterialApp(
     title: 'My App',
     //home: ListScreen(),
     home: list_view_visible(),

   );
 }
}


class ListScreen extends StatefulWidget {
 const ListScreen({Key? key}) : super(key: key);


 @override
 State<ListScreen> createState() => ListScreenState();
}


Completer<void> indexChangedCompleter = Completer<void>();

  // Stream to listen for changes in the index variable
  StreamController<int> indexChangeStreamController = StreamController<int>();
  Stream<int> indexChangeStream = indexChangeStreamController.stream;

  // Function to trigger completion when index changes
  void onIndexChanged(int newIndex) {
    if (!indexChangedCompleter.isCompleted) {
      indexChangedCompleter.complete();
    }
    indexChangeStreamController.add(newIndex);
  }





class ListScreenState extends State<ListScreen> {














Future<void> setStatefunction() async {
  setState(() {
     });
 }

  
 String kPickedNumber = '';
 String kPickedName = '';
 PhoneContact? _phoneContact;


 // FUNCTION
 String phoneNumber = "+44 7845967135";
 Future<void> _makePhoneCall(String phoneNumber) async {
   final Uri launchUri = Uri(
     scheme: 'tel',
     path: phoneNumber,
   );
   await launchUrl(launchUri);
 }


 // FUNCTION


 //WHOLE FUNCTIONS PASTED FROM EXAMPLE OF URL LAUNCHER


 bool _hasCallSupport = false;
 Future<void>? _launched;
 final String _phone = '';


 @override
 void initState() {
   super.initState();

    fetchContactsAsArray(selectedList);

   getListNames();



   
   fetchDataFromFirestore(userId);
   // Check for phone call support.
   canLaunchUrl(Uri(scheme: 'tel', path: '123')).then((bool result) {
     setState(() {
       _hasCallSupport = result;
     });
   });
 }





 Future<void> _launchInBrowser(Uri url) async {
   if (!await launchUrl(
     url,
     mode: LaunchMode.externalApplication,
   )) {
     throw Exception('Could not launch $url');
   }
 }


 Future<void> _launchInWebViewOrVC(Uri url) async {
   if (!await launchUrl(
     url,
     mode: LaunchMode.inAppWebView,
     webViewConfiguration: const WebViewConfiguration(
       headers: <String, String>{'my_header_key': 'my_header_value'},
     ),
   )) {
     throw Exception('Could not launch $url');
   }
 }


 Future<void> _launchInWebViewWithoutJavaScript(Uri url) async {
   if (!await launchUrl(
     url,
     mode: LaunchMode.inAppWebView,
     webViewConfiguration: const WebViewConfiguration(enableJavaScript: false),
   )) {
     throw Exception('Could not launch $url');
   }
 }


 Future<void> _launchInWebViewWithoutDomStorage(Uri url) async {
   if (!await launchUrl(
     url,
     mode: LaunchMode.inAppWebView,
     webViewConfiguration: const WebViewConfiguration(enableDomStorage: false),
   )) {
     throw Exception('Could not launch $url');
   }
 }


 Future<void> _launchUniversalLinkIos(Uri url) async {
   final bool nativeAppLaunchSucceeded = await launchUrl(
     url,
     mode: LaunchMode.externalNonBrowserApplication,
   );
   if (!nativeAppLaunchSucceeded) {
     await launchUrl(
       url,
       mode: LaunchMode.inAppWebView,
     );
   }
 }


 Widget _launchStatus(BuildContext context, AsyncSnapshot<void> snapshot) {
   if (snapshot.hasError) {
     return Text('Error: ${snapshot.error}');
   } else {
     return const Text('');
   }
 }


 //WHOLE FUNCTIONS PASTED FROM EXAMPLE OF URL LAUNCHER




String get userId => AuthService.firebase().currentUser!.id;


//  Future<void> updateContactData() async {
//    try {








    


//      // Get the Firestore instance
//      FirebaseFirestore firestore = FirebaseFirestore.instance;


//      // Create a reference to the document you want to update (replace 'document_id' with the actual document ID)
//      DocumentReference contactRef = firestore.collection('lists').doc('7Ks2XyfA9a2IwdPHqHga');


//      // Create a map with the updated data (replace 'new_name' and 'new_phone_number' with the actual updated values)
//      Map<String, dynamic> updatedData = {
//        //'contact_name': 'Supriya Gorai',
//        'contact_name': kPickedName,
//        //'contact_phone_number': '+44 7845967135',
//        'contact_phone_number': kPickedNumber,
//        'user_id': userId,
//      };


//      // Update the document in Firestore
//      await contactRef.update(updatedData);
    


//      print('Data updated successfully!');
//    } catch (e) {
//      print('Error updating data in Firestore: $e');
//    }
//  }






// CODE TO MAKE A NEW DOCUMENT EACH TIME


Future<void> addNewContactData() async {
 try {
   // Get the Firestore instance
   FirebaseFirestore firestore = FirebaseFirestore.instance;


   // Create a reference to the 'lists' collection
   CollectionReference listsRef = firestore.collection('lists');
    

   // Create a map with the new contact data
   Map<String, dynamic> newContactData = {
     'contact_name': kPickedName,
     'contact_phone_number': kPickedNumber,
     'user_id': userId,
     'call_duration': '0',
     'list_name': listName,
   };


   // Add the new document with an auto-generated ID
   await listsRef.add(newContactData);


   print('New contact data added successfully!');
 } catch (e) {
   print('Error adding new contact data to Firestore: $e');
 }
}



// MULTIPLE LIST CODEE
Future<void> addNewList(String listName) async {
  try {
    // Get the Firestore instance
    FirebaseFirestore firestore = FirebaseFirestore.instance;

    // Create a reference to the 'lists_collection' collection
    CollectionReference listsRef = firestore.collection('lists_collection');
     fetchDataFromFirestore(userId);

    // Create a map with the new list data
    Map<String, dynamic> newListData = {
      'list_name': listName,
      'user_id': userId,
      'current_index': index,
      'total_documents': totalDocuments,
    };

    // Add the new document with an auto-generated ID
    await listsRef.add(newListData);

    print('New list added successfully!');
  } catch (e) {
    print('Error adding new list to Firestore: $e');
  }
}


void showListDialog(BuildContext context) {
    TextEditingController listNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create New List'),
          content: TextField(
            controller: listNameController,
            decoration: const InputDecoration(hintText: 'Enter list name'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();

              },
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                String listName = listNameController.text;
                addNewList(listName);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }






 //String selectedList = '';    // THIS VARIABLE WILL COME FROM FIREBASE_SERIVICES
  List<String> listNames = []; // To store the list names from Firestore

  Future<void> addNewContactDataToList(selectedList) async {

    try {
      if (selectedList.isEmpty) {
        print('Please Upload Contacts.');
        return;
      }

      FirebaseFirestore firestore = FirebaseFirestore.instance;
      CollectionReference listsRef = firestore.collection('lists');


  // Query to get the document with the highest contact_index
    QuerySnapshot querySnapshot = await listsRef
        .orderBy('contact_index', descending: true)
        .limit(1)
        .get();

    int largestContactIndex = 0;
    if (querySnapshot.docs.isNotEmpty) {
      largestContactIndex = querySnapshot.docs.first['contact_index'];
    }

    print('The largest contact_index is: $largestContactIndex');








      Map<String, dynamic> newContactData = {
        'contact_name': kPickedName,
        'contact_phone_number': kPickedNumber,
        'user_id': userId,
        'call_duration': '0',
        // 'list_name': listName,
        'list_name': selectedList,
        'contact_index': largestContactIndex + 1,
      };

      // Get the reference to the selected list
      DocumentReference selectedListRef = listsRef.doc(selectedList);

      // Add the new contact data to the selected list
      //await selectedListRef.collection('contacts').add(newContactData); THIS CODE WORKS EXTREMELy wELL BUT TEST IT LATER

      //await selectedListRef.collection('lists').add(newContactData);

      await listsRef.add(newContactData);
      print('New contact data added successfully!');
    } catch (e) {
      print('Error adding new contact data to Firestore: $e');
    }
  }




  Future<void> getListNames() async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    QuerySnapshot snapshot = await firestore.collection('lists_collection').get();

    List<String> names = snapshot.docs.map((DocumentSnapshot doc) {
      return doc.get('list_name') as String;
    }).toList();
    names.sort();

    setState(() {
      listNames = names;
    });
  }







// MULTIPLE LIST CODEE







// TO READ DATA




void fetchDocumentsInOrder() {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  CollectionReference listsRef = firestore.collection('lists');

  // You can add additional constraints to the query if needed, such as filtering by user ID
  Query query = listsRef.where('user_id', isEqualTo: userId);

  // Fetch the documents and listen for updates
  query.snapshots().listen((QuerySnapshot snapshot) {
    // Iterate through the documents
    for (QueryDocumentSnapshot docSnapshot in snapshot.docs) {
      // Handle the nullable return value and cast it to Map<String, dynamic>?
      Map<String, dynamic>? documentData = docSnapshot.data() as Map<String, dynamic>?;

      // Now you can do whatever you want with the document data
      if (documentData != null) {
        // For example, print the contact name and phone number
        print('Contact Name: ${documentData['contact_name']}');
        print('Contact Phone Number: ${documentData['contact_phone_number']}');
        print('User ID: ${documentData['user_id']}');
        print('Call Duration: ${documentData['call_duration'] ?? "Not available"}');
        print('List NAme: ${documentData['list_name'] ?? "Not available"}');
        // Here you can perform any logic or operations on the document
        // You can cycle through the documents or use them as needed
      }
    }
  });
}





int totalDocuments = 0; 

Future<void> fetchDocumentAtIndexAndShowDialog(int index, selectedList) async {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  CollectionReference listsRef = firestore.collection('lists');

  // You can add additional constraints to the query if needed, such as filtering by user ID
  Query query = listsRef
        .where('user_id', isEqualTo: userId)
        .where('list_name', isEqualTo: selectedList);

  QuerySnapshot snapshot = await query.get();
  List<QueryDocumentSnapshot> documentSnapshots = snapshot.docs;
  totalDocuments = snapshot.size; // Total number of documents

  print('Total number of documents: $totalDocuments');

  if (index >= 0 && index < documentSnapshots.length) {
    QueryDocumentSnapshot docSnapshot = documentSnapshots[index];
    Map<String, dynamic>? documentData = docSnapshot.data() as Map<String, dynamic>?;

    if (documentData != null) {
      print('Contact Name: ${documentData['contact_name']}');
      print('Contact Phone Number: ${documentData['contact_phone_number']}');
      print('User ID: ${documentData['user_id']}');
      print('Call Duration: ${documentData['call_duration'] ?? "Not available"}');
      print('List Name: ${documentData['list_name'] ?? "Not available"}');

      // Here you can perform any logic or operations on the document
      // For example, you can wait for the user to call the contact

      // Call the dialog function after fetching the document
      showContactDialog(
        documentData['contact_name'],
        documentData['contact_phone_number'],
        documentData['call_duration'] ?? "Not available",
        
      );
      print(index);
    }
  } else {
    print('Invalid index. Document not found.');
    print(index);
  }









}












//int index = 0; // DEFINITION OF CALL CYCLE INDEX

Future<void> showContactDialog(String contactName, String contactPhoneNumber, String callDuration) async {
  showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Contact Information. Press Yes when the call ends'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: $contactName'),
            Text('Phone Number: $contactPhoneNumber'),
            //Text('Call Duration: $callDuration'),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              // Perform any action you want when the user clicks a button
              previousIndex = index;
              index = index + 1;
              Navigator.of(context).pop();
              print(index);
              print(previousIndex);
              fetchDocumentAtIndexAndShowDialog(index, selectedList);
              
            },
            child: const Text('Yes'),
          ),
          TextButton(
            onPressed: () async  {
              // Perform any action you want when the user clicks a button
              Navigator.of(context).pop();
              // CODE HERE TO UPDATE TO FIREBASE THE TOTAL DOCUMENTS AND CURRENT INDEX NUMBER

            // FirebaseFirestore firestore = FirebaseFirestore.instance;
            // CollectionReference listsRef = firestore.collection('lists_collection');
            // QuerySnapshot querySnapshot = await listsRef.where('list_name', isEqualTo: selectedList).get();
            // DocumentReference documentRef = querySnapshot.docs.first.reference;
            // int current_Index = index + 1;
            // await documentRef.update({'current_index': current_Index});
            // await documentRef.update({'total_documents': totalDocuments});


    FirebaseFirestore firestore = FirebaseFirestore.instance;
    CollectionReference listsRef = firestore.collection('lists_collection');
    QuerySnapshot querySnapshot = await listsRef
        .where('list_name', isEqualTo: selectedList)
        .where('user_id', isEqualTo: userId) // Corrected filter syntax
        .get();

    DocumentReference documentRef = querySnapshot.docs.first.reference;

    int currentIndex = index + 1;

    await documentRef.update({
        'current_index': currentIndex,
        'total_documents': totalDocuments,

    });
     
            },
            child: const Text('Close'),
          ),
        ],
      );
    },
  );



  await Future.delayed(const Duration(seconds: 5));

 
_makePhoneCall(contactPhoneNumber);

}

// TO READ DATA


 int index = 0;
 int previousIndex = 0;
List<Map<String, dynamic>> documentArray = [];

void fetchDocumentsInOrderAndSaveToArray() {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  CollectionReference listsRef = firestore.collection('lists');

  // Use the 'orderBy' method to sort documents by a specific field (e.g., 'contact_name')
  // For ascending order, use 'asc' and for descending order, use 'desc'
  Query query = listsRef.orderBy('contact_name', descending: true);

  // Fetch the documents and listen for updates
  query.snapshots().listen((QuerySnapshot snapshot) {
    // Clear the array when new data is received to avoid duplicates
    documentArray.clear();

    // Iterate through the documents and add them to the array
    for (QueryDocumentSnapshot docSnapshot in snapshot.docs) {
      // Handle the nullable return value and cast it to Map<String, dynamic>?
      Map<String, dynamic>? documentData = docSnapshot.data() as Map<String, dynamic>?;

      // Add the document data to the array if it's not null
      if (documentData != null) {
        documentArray.add(documentData);
      }
    }

    // Increment the index for the next iteration
    index++;
  });
}

// Function to access the document data through the index array
Map<String, dynamic> getDocumentByIndex(int index) {
  if (index >= 0 && index < documentArray.length) {
    print (documentArray[index]);
    return documentArray[index];
    
  } else {
    // Handle index out of bounds or other error scenarios
    return {};
  }
}



// TO TRY AND CYCLE THROUGH THE DATA


Future<void> cycleThroughContacts() async {
 FirebaseFirestore firestore = FirebaseFirestore.instance;
 CollectionReference listsRef = firestore.collection('lists');


 // Use the 'orderBy' method to sort documents by a specific field (e.g., 'contact_name')
 // For ascending order, use 'asc' and for descending order, use 'desc'
 Query query = listsRef.orderBy('contact_name', descending: false);


 // You can also add additional constraints to the query, for example, to filter by a specific user ID
  query = query.where('user_id', isEqualTo: userId);


 // Fetch the documents
 QuerySnapshot snapshot = await query.get();


 // Iterate through the documents
 for (QueryDocumentSnapshot docSnapshot in snapshot.docs) {
   // Handle the nullable return value and cast it to Map<String, dynamic>?
   Map<String, dynamic>? documentData = docSnapshot.data() as Map<String, dynamic>?;


   // Now you can do whatever you want with the document data
   if (documentData != null) {
     // For example, print the contact name and phone number
     print('Contact Name: ${documentData['contact_name']}');
     print('Contact Phone Number: ${documentData['contact_phone_number']}');
     print('User ID: ${documentData['user_id']}');
     print('Call Duration: ${documentData['call_duration']}');
     print('List Name: ${documentData['list_name']}');


     // Here you can perform any logic or operations on the document
     // For example, you can wait for the user to call the contact
    


     //await waitForUserToCallContact();
    
    // _startCallTimer();
     // After the user has called the contact, you can proceed to the next contact
   }
 }
}








// TO TRY AND CYCLE THROUGH THE DATA








Timer? _callTimer;
 int _elapsedSeconds = 0;






void _startCallTimer(Function setState) {
 _callTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
   setState(() {
     _elapsedSeconds++;
   });
 });
}




 @override
 void dispose() {
   _callTimer?.cancel();
   super.dispose();
 }




 void _stopTimer() {
   _callTimer?.cancel();
 }








// DIALOG WHEN USER RETURNS TO APP


Future<void> _showCallFinishedDialog(String name) async {
  // Start the timer when the dialog is shown
  _startCallTimer(setState); // Start the timer

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Phone Call Finished'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              
              children: [
                Text('Elapsed Time: $_elapsedSeconds seconds'),
                const SizedBox(height: 20),
                Text('Call: $name'), // Display the parameter text in the dialog
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                     int index1 = 0;   
                          Map<String, dynamic> documentDataAtIndex0 = getDocumentByIndex(index1);
        
                _makePhoneCall(({documentDataAtIndex0['contact_phone_number']}).toString());  
                  index1 = index1 + 1;
                  setState(() {
                    _elapsedSeconds = 0; // Reset the counter
                  });
                  Navigator.of(context).pop();
                },
                child: const Text('Yes'),
              ),
              TextButton(
                onPressed: () {
                   
                  Navigator.of(context).pop();
                },
                child: const Text('No'),
              ),
            ],
          );
        },
      );
    },
  );
}







// Future<void> showContactDialog(String contactName, String contactPhoneNumber, String callDuration) async {
//   showDialog<void>(
//     context: context,
//     builder: (BuildContext context) {
//       return AlertDialog(
//         title: Text('Contact Information'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Name: $contactName'),
//             Text('Phone Number: $contactPhoneNumber'),
//             Text('Call Duration: $callDuration'),
//           ],
//         ),
//         actions: <Widget>[
//           TextButton(
//             onPressed: () {
//               // Perform any action you want when the user clicks a button
//               Navigator.of(context).pop();
//             },
//             child: const Text('Close'),
//           ),
//         ],
//       );
//     },
//   );
// }

// DIALOG WHEN USER RETURNS TO APP





// Dropdown

// Future<void> fetchDataFromFirestore() async {
//     try {
//       QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('lists_collection').get();
//       print("This is function on the lisT_view dart page");

//       setState(() {
//         list = querySnapshot.docs.map((doc) => doc['list_name'] as String).toList();

//         // If the list is not empty, set the dropdown value to the first item
//         if (list.isNotEmpty) {
//           dropdownValue = list.first;
//         }
        
//       });
//     } catch (error) {
//       showErrorDialog(context, "Could not load...");
      
//     }
//   }


Future<void> fetchDataFromFirestore(String userId) async {
  try {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('lists_collection')
        .where('user_id', isEqualTo: userId)
        .get();

    print("This is function on the lisT_view dart page");

    setState(() {
      list = querySnapshot.docs.map((doc) => doc['list_name'] as String).toList();

      // If the list is not empty, set the dropdown value to the first item
      if (list.isNotEmpty) {
        dropdownValue = list.first;
      }
    });
  } catch (error) {
    showErrorDialog(context, "Could not load...");
  }
}







 
// CODE TO DISPLAY CONTACTS NAME IN LISTS



List<String> listContacts = [];
//late String listContactsJoined;
String listContactsJoined = "";

  Future<void> fetchContactsAsArray(selectedList) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    //QuerySnapshot snapshot = await firestore.collection('lists_collection').get();

        QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('lists')
        .where('user_id', isEqualTo: userId)
        .where('list_name', isEqualTo: selectedList)
        .get();



    List<String> listContacts = snapshot.docs.map((DocumentSnapshot doc) {
      return doc.get('contact_name') as String;
    }).toList();

    // Convert the listIndex values to double and update weeklySummary
    // weeklySummary = listIndex.map((int value) => value.toDouble()).toList();
    listContacts = listContacts.map((String value) => value.toString()).toList();

    print(listContacts);
    
    listContactsJoined = listContacts.join(", ");
    print(listContactsJoined);

      // This line allows the data to be sent to the dialer view...
    // Trigger a rebuild of the UI
    setState(() {});

    if (listContacts.isEmpty) {
    
    showWelcomeDialog(context);
      }

      listContactsJoinedforDialerView = listContacts.join(", "); 

  }


// CODE TO DISPLAY CONTACTS NAME IN LISTS






// Dropdown









 @override
 Widget build(BuildContext context) {
   //final Uri toLaunch = Uri(scheme: 'https', host: 'www.mavenswood.com');


   return Scaffold(

  //     floatingActionButton: ElevatedButton(
  //       style: ElevatedButton.styleFrom(
  //   primary: Colors.grey[200], // Set to your background color
  //   onPrimary: Colors.grey[200], // Set to your background color
  //   shape: RoundedRectangleBorder(
  //     borderRadius: BorderRadius.circular(8.0),
  //   ),
  //   padding: const EdgeInsets.all(12.0),
  // ),
  //       child: Icon(Icons.add, size:30, color: textColor(context)),
  //       onPressed:() {
  //         _showListDialog(context
  //         );},
  //     ),


      backgroundColor: const Color.fromRGBO(248, 225, 209, 1),




     appBar: AppBar(
       title: const Text('List Builder View'),
       centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
             fetchDataFromFirestore(userId);
             fetchContactsAsArray(selectedList);
            },
            icon: const Icon(Icons.refresh),
          ),
           PopupMenuButton(
            onSelected: (value) async {
              switch (value){

                case MenuAction.logout:
                  final shouldLogout = await showLogOutDialog(context);
                  if (shouldLogout) {
                    await FirebaseAuth.instance.signOut();
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/login/',
                    (_) => false,
                    );
                  }
              }
            },
            itemBuilder: (context) {
              return const [  
                 PopupMenuItem<MenuAction>(

                value: MenuAction.logout, 
                child: Text("Log out"),
              
              ),
        ]; 
                

            }
          ),
        ]
     ),
    //  bottomNavigationBar: buildBottomNavigationBar(context),
     //bottomNavigationBar: Gbar(),
    
     body: ListView(
       children: <Widget>[













DropdownButton<String>(
      value: dropdownValue,
      icon: const Icon(Icons.arrow_downward),
      elevation: 16,
      style: const TextStyle(color: Colors.deepPurple),
      underline: Container(
        height: 2,
        color: Colors.deepPurpleAccent,
      ),
      onChanged: (String? value) {
        // This is called when the user selects an item.
        setState(() {
          dropdownValue = value!;
          selectedList = dropdownValue;
          listName = dropdownValue;
        });
      },
      items: list.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
    ),






        //  Column(
        //    mainAxisAlignment: MainAxisAlignment.center,
        //    children: <Widget>[

            //  Text("Picked Contact Name is : $kPickedName"),
            //  const SizedBox(height: 20),
            //  Text("Picked Contact Number is : $kPickedNumber"),
            //  const SizedBox(height: 20),



            //   Padding(
            //     padding: const EdgeInsets.all(12.0),
            //     child:   Text(
            //       "Contacts in $selectedList: $listContactsJoined",
                
            //     ),
            //   ),


          
        //    ]),





// Card Code




Row(
   children: <Widget>[ 
    Expanded( 
      child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Image.asset(
                  //   ImgSample.get('relaxing-man.png'),
                  //   height: 160,
                  //   width: double.infinity,
                  //   fit: BoxFit.cover,
                  // ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          "Create New List",
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey[800],
                          ),
                        ),
                        Container(height: 10),
                        Text(
                          
                          "Here you can name your own list...        And create as many as you like!",
                          
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[700],
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            const Spacer(),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.transparent,
                              ),
                              child: const Text(
                                "Add a new list",
                                style: TextStyle(color: MyColorsSample.accent),
                              ),
                              onPressed: () {

                                showListDialog(context);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(height: 5),
                ],
              ),
            ),
            ),
   
             Expanded( 
      child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Image.asset(
                  //   ImgSample.get('relaxing-man.png'),
                  //   height: 160,
                  //   width: double.infinity,
                  //   fit: BoxFit.cover,
                  // ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          "Upload Contact",
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey[800],
                          ),
                        ),
                        Container(height: 10),
                        Text(
                          "Upload contacts from your native contacts book. Select list from the dropdown above",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[700],
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            const Spacer(),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.transparent,
                              ),
                              child: const Text(
                                "Upload",
                                style: TextStyle(color: MyColorsSample.accent),
                              ),
                              onPressed: () async {

                                    await fetchContactsAsArray(selectedList);   // THIS IS REQURESTED TWICE

                                    bool permission = await FlutterContactPicker.requestPermission();


                                  if (permission) {
                                    if (await FlutterContactPicker.hasPermission()) {
                                      _phoneContact = await FlutterContactPicker.pickPhoneContact();


                                      if (_phoneContact != null) {
                                        if (_phoneContact!.fullName != null && _phoneContact!.fullName!.isNotEmpty) {
                                          setState(() {
                                            kPickedName = _phoneContact!.fullName.toString();
                                          });
                                        }
                                        if (_phoneContact!.phoneNumber != null &&
                                            _phoneContact!.phoneNumber!.number!.isNotEmpty) {
                                          setState(() {
                                            kPickedNumber = _phoneContact!.phoneNumber!.number.toString();
                                          });
                                        }
                                      }
                                    }
                                  }


                                addNewContactDataToList(selectedList);

                                fetchDocumentsInOrder();
                                await fetchContactsAsArray(selectedList);       // THIS IS REQURESTED TWICE
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(height: 5),
                ],
              ),
            ),
            )
   
            
            ]
        
            
            
            ),





// Second line of Cards...



Row(
   children: <Widget>[ 
    Expanded( 
      child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Image.asset(
                  //   ImgSample.get('relaxing-man.png'),
                  //   height: 160,
                  //   width: double.infinity,
                  //   fit: BoxFit.cover,
                  // ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          "Delete ",
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey[800],
                          ),
                        ),
                        Container(height: 10),
                        Text(
                          
                          "Delete all contacts, all lists, or all contacts from '$selectedList'. Choose after clicking below!",
                          
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[700],
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            const Spacer(),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.transparent,
                              ),
                              child: const Text(
                                "Delete...",
                                style: TextStyle(color: MyColorsSample.accent),
                              ),
                              onPressed: () async{

                                await showDeleteListViewDialog(context);
                                
                             
                              await fetchDataFromFirestore(userId);
                                await fetchContactsAsArray(selectedList);
                                
                                
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(height: 5),
                ],
              ),
            ),
            ),
   
             Expanded( 
      child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Image.asset(
                  //   ImgSample.get('relaxing-man.png'),
                  //   height: 160,
                  //   width: double.infinity,
                  //   fit: BoxFit.cover,
                  // ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          "Guide",
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey[800],
                          ),
                        ),
                        Container(height: 10),
                        Text(
                          "Here you can get a guide to create a list and upload contacts to the list?",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[700],
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            const Spacer(),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.transparent,
                              ),
                              child: const Text(
                                "Guide",
                                style: TextStyle(color: MyColorsSample.accent),
                              ),
                              onPressed: () async {
                                    Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const OnBoardingScreen(),
                                  ),
                                );  
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(height: 5),
                ],
              ),
            ),
            )
   
            
            ]
        
            
            
            ),



// third Line of cards



Row(
   children: <Widget>[ 
    Expanded( 
      child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Image.asset(
                  //   ImgSample.get('relaxing-man.png'),
                  //   height: 160,
                  //   width: double.infinity,
                  //   fit: BoxFit.cover,
                  // ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          "Uploading Contacts...",
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey[800],
                          ),
                        ),
                        Container(height: 10),
                        Text(
                          
                          "Picked Contact Name: $kPickedName.               Picked Contact Number: $kPickedNumber.",
                          
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[700],
                          ),
                        ),
                        const Row(
                          children: <Widget>[
                            Spacer(),
                            // TextButton(
                            //   style: TextButton.styleFrom(
                            //     foregroundColor: Colors.transparent,
                            //   ),
                            //   child: const Text(
                            //     "Add a new list",
                            //     style: TextStyle(color: MyColorsSample.accent),
                            //   ),
                            //   onPressed: () {

                            //     _showListDialog(context);
                            //   },
                            // ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(height: 5),
                ],
              ),
            ),
            ),
   
             Expanded( 
      child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Image.asset(
                  //   ImgSample.get('relaxing-man.png'),
                  //   height: 160,
                  //   width: double.infinity,
                  //   fit: BoxFit.cover,
                  // ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          "Uploaded Contacts",
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey[800],
                          ),
                        ),
                        Container(height: 10),
                        Text(
                          "Contacts in $selectedList: $listContactsJoined",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[700],
                          ),
                        ),
                        const Row(
                          children: <Widget>[
                            Spacer(),
                            // TextButton(
                            //   style: TextButton.styleFrom(
                            //     foregroundColor: Colors.transparent,
                            //   ),
                            //   child: const Text(
                            //     "Upload",
                            //     style: TextStyle(color: MyColorsSample.accent),
                            //   ),
                            //   onPressed: () async {

                            //         await fetchContactsAsArray(selectedList);   // THIS IS REQURESTED TWICE

                            //         bool permission = await FlutterContactPicker.requestPermission();


                            //       if (permission) {
                            //         if (await FlutterContactPicker.hasPermission()) {
                            //           _phoneContact = await FlutterContactPicker.pickPhoneContact();


                            //           if (_phoneContact != null) {
                            //             if (_phoneContact!.fullName != null && _phoneContact!.fullName!.isNotEmpty) {
                            //               setState(() {
                            //                 kPickedName = _phoneContact!.fullName.toString();
                            //               });
                            //             }
                            //             if (_phoneContact!.phoneNumber != null &&
                            //                 _phoneContact!.phoneNumber!.number!.isNotEmpty) {
                            //               setState(() {
                            //                 kPickedNumber = _phoneContact!.phoneNumber!.number.toString();
                            //               });
                            //             }
                            //           }
                            //         }
                            //       }
                            //     addNewContactDataToList(selectedList);
                            //       fetchDocumentsInOrder();
                            //     await fetchContactsAsArray(selectedList);       // THIS IS REQURESTED TWICE
                            //   },
                            // ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(height: 5),
                ],
              ),
            ),
            )
   
            
            ]
        
            
            
            ),


ElevatedButton(
            onPressed: () {
              // This code runs when the button is pressed
                        Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => list_view_visible(),
            ),
          );
                      
            },
            child: Text('Press Me'),
          ),
















          //  ],   
        //  ),


       ],
     ),










   );
 }
}



bool isLoading = true;