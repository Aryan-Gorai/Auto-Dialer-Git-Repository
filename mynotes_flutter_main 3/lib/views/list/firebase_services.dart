import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bloc/bloc.dart';

import 'package:flutter/material.dart';

import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:flutter_application_1/utilities/dialogs/error_dialog.dart';

import 'package:flutter_application_1/views/dialer/dialer.dart';
//import 'package:flutter_application_1/views/dialer/dialer_backup.dart';
import 'package:flutter_application_1/views/list/list_view.dart';
import 'package:flutter_application_1/views/list/list_view_visible.dart';

import 'package:flutter_application_1/views/onBoarding/onBoarding.dart';
import 'package:flutter_application_1/views/reports/reports_view.dart';
import 'package:fluttercontactpicker/fluttercontactpicker.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

import 'package:url_launcher/url_launcher.dart';
import 'dart:async';



 bool hasCallSupport = false;
 Future<void>? launched;
 String phone = '';
 String selectedList = '';
 
  List<String> listNames = []; // To store the list names from Firestore

String get userId => AuthService.firebase().currentUser!.id;

String kPickedNumber = '';
 String kPickedName = '';
 PhoneContact? phoneContact;

// CODE FOR DROPDOWN
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
List<String> list = <String>[];
String dropdownValue = list.first;
String listName = '';
// CODE FOR DROPDOWN



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



  
 


 // FUNCTION
 String phoneNumber = "+44 7845967135";
 Future<void> makePhoneCall(String phoneNumber) async {
   final Uri launchUri = Uri(
     scheme: 'tel',
     path: phoneNumber,
   );
   await launchUrl(launchUri);
 }




 Future<void> launchInBrowser(Uri url) async {
   if (!await launchUrl(
     url,
     mode: LaunchMode.externalApplication,
   )) {
     throw Exception('Could not launch $url');
   }
 }


 Future<void> launchInWebViewOrVC(Uri url) async {
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


 Future<void> launchInWebViewWithoutJavaScript(Uri url) async {
   if (!await launchUrl(
     url,
     mode: LaunchMode.inAppWebView,
     webViewConfiguration: const WebViewConfiguration(enableJavaScript: false),
   )) {
     throw Exception('Could not launch $url');
   }
 }


 Future<void> launchInWebViewWithoutDomStorage(Uri url) async {
   if (!await launchUrl(
     url,
     mode: LaunchMode.inAppWebView,
     webViewConfiguration: const WebViewConfiguration(enableDomStorage: false),
   )) {
     throw Exception('Could not launch $url');
   }
 }


 Future<void> launchUniversalLinkIos(Uri url) async {
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


 Widget launchStatus(BuildContext context, AsyncSnapshot<void> snapshot) {
   if (snapshot.hasError) {
     return Text('Error: ${snapshot.error}');
   } else {
     return const Text('');
   }
 }


 //WHOLE FUNCTIONS PASTED FROM EXAMPLE OF URL LAUNCHER



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
    fetchDataFromFirestore();

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






  


 PhoneContact? _phoneContact;
Future<void> upload_button_on_dialer_contacts_view(selectedList ) async{

                                      bool permission = await FlutterContactPicker.requestPermission();


                                  if (permission) {
                                    if (await FlutterContactPicker.hasPermission()) {
                                      _phoneContact = await FlutterContactPicker.pickPhoneContact();


                                      if (_phoneContact != null) {
                                        if (_phoneContact!.fullName != null && _phoneContact!.fullName!.isNotEmpty) {

                                            kPickedName = _phoneContact!.fullName.toString();
                                          
                                        }
                                        if (_phoneContact!.phoneNumber != null &&
                                            _phoneContact!.phoneNumber!.number!.isNotEmpty) {

                                            kPickedNumber = _phoneContact!.phoneNumber!.number.toString();
                                        }
                                      }
                                    }
                                  }


                                await addNewContactDataToList(selectedList);
}









void showListDialogForIntroScreen(BuildContext context) {
    TextEditingController listNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Create New List'),
          content: TextField(
            controller: listNameController,
            decoration: InputDecoration(hintText: 'Enter list name'),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();

              },
            ),
            TextButton(
              child: Text('OK'),
              onPressed: () {
                String listName = listNameController.text;
                addNewList(listName);
                selectedList = listName;
                Navigator.of(context).pop();
                fetchDataFromFirestore();
                getListNames();
                controller.jumpToPage(1);
              },
            ),
          ],
        );
      },
    );
  }






void showListDialogForIntroScreen1(BuildContext context) {
 TextEditingController listNameController = TextEditingController();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Create New List'),
        content: TextField(
          controller: listNameController,
          decoration: InputDecoration(hintText: 'Enter list name'),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text('OK'),
            onPressed: () async {
              String listName = listNameController.text;
              addNewList(listName);
              Navigator.of(context).pop();

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) {
                  return FutureBuilder(
                    future: Future.delayed(Duration(seconds: 3)),
                    builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return AlertDialog(
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Loading...'),
                            ],
                          ),
                        );
                      } else {
                        // Perform actual tasks after the delay
                        fetchDataFromFirestore();
                        getListNames();

                        // Jump to page 1
                        controller.jumpToPage(1);

                        return Container(); // Return an empty container
                      }
                    },
                  );
                },
              );
            },
          ),
        ],
      );
    },
  );
}


// void showListDialog(BuildContext context) {
//     TextEditingController listNameController = TextEditingController();

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Create New List'),
//           content: TextField(
//             controller: listNameController,
//             decoration: InputDecoration(hintText: 'Enter list name'),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Cancel'),
//               onPressed: () {
//                 Navigator.of(context).pop();

//               },
//             ),
//             TextButton(
//               child: Text('OK'),
//               onPressed: () {
//                 String listName = listNameController.text;
//                 addNewList(listName);
//                 Navigator.of(context).pop();
//                 fetchDataFromFirestore();
//                 getListNames();
                
//               },
//             ),
//           ],
//         );
//       },
//     );











    
//   }



Future<void> showListDialog(BuildContext context) async {
  TextEditingController listNameController = TextEditingController();

  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Create New List'),
        content: TextField(
          controller: listNameController,
          decoration: InputDecoration(hintText: 'Enter list name'),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text('OK'),
            onPressed: () {
              String listName = listNameController.text;
              addNewList(listName);
              Navigator.of(context).pop();
              fetchDataFromFirestore();
              getListNames();
            },
          ),
        ],
      );
    },
  );
}











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
    listNames = names;
    // setState(() {
    //   listNames = names;
    // });
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

Future<void> fetchDocumentAtIndexAndShowDialog(BuildContext context, int index, selectedList) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    QuerySnapshot snapshot = await firestore
        .collection('lists')
        .where('user_id', isEqualTo: userId)
        .where('list_name', isEqualTo: selectedList)
        .orderBy("contact_index")
        .get();



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
        context,
        documentData['contact_name'],
        documentData['contact_phone_number'],
        documentData['call_duration'] ?? "Not available",
        
      );
      print(index);
    }
  } else {
    print('Invalid index. Document not found.');
    print(index);



      await showErrorDialog(context, 'Contact not found, reset index, or upload contacts, or select a list from the dropdown');
  


    // WRite an if statement here to say if the index == the total documents, then push the calculation to the graph, by pushing index to firebase.or else, show the dialog.
    

    

    } 

  }








// CODE TO DISPLAY CONTACTS NAME IN LISTS



// CODE TO DISPLAY CONTACTS NAME IN LISTS
















//int index = 0; // DEFINITION OF CALL CYCLE INDEX

Future<void> showContactDialog(BuildContext context, String contactName, String contactPhoneNumber, String callDuration) async {
  showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Contact Information. Press Next when the call ends'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: $contactName'),
            Text('Phone Number: $contactPhoneNumber'),
            //Text('Call Duration: $callDuration'),
            
              Padding(
                padding: const EdgeInsets.all(12.0),
                child:   Text(
                  "Contacts in $selectedList: $listContactsJoinedforDialerView",
                
                ),
              ),

          ],
        ),
        actions: <Widget>[
          
            TextButton(
            onPressed: () {
              makePhoneCall(contactPhoneNumber);
              
            },
            child: const Text('Launch Call Again'),
          ),

          TextButton(
            onPressed: () async{
              // Perform any action you want when the user clicks a button
              previousIndex = index;
              index = index + 1;
              Navigator.of(context).pop();
              print(index);
              print(previousIndex);
              fetchDocumentAtIndexAndShowDialog(context, index, selectedList);

// if (index == totalDocuments) {    FirebaseFirestore firestore = FirebaseFirestore.instance;
//     CollectionReference listsRef = firestore.collection('lists_collection');
//     QuerySnapshot querySnapshot = await listsRef
//         .where('list_name', isEqualTo: selectedList)
//         .where('user_id', isEqualTo: userId) // Corrected filter syntax
//         .get();

//     DocumentReference documentRef = querySnapshot.docs.first.reference;

//     int current_Index = index + 1;

//     await documentRef.update({
//         'current_index': current_Index,
//         'total_documents': totalDocuments,

//     });
//     }


              
            },
            child: const Text('Next'),
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

    int current_Index = index + 1;

    await documentRef.update({
        'current_index': current_Index,
        'total_documents': totalDocuments,

    });
     
            },
            child: const Text('Close'),
          ),
        ],
      );
    },
  );



  await Future.delayed(Duration(seconds: 5));

 
makePhoneCall(contactPhoneNumber);

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








Timer? callTimer;
 int elapsedSeconds = 0;






void startCallTimer(Function setState) {
 callTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
   setState(() {
     elapsedSeconds++;
   });
 });
}




//  @override
//  void dispose() {
//    _callTimer?.cancel();
//    super.dispose();
//  }




 void _stopTimer() {
   callTimer?.cancel();
 }








// DIALOG WHEN USER RETURNS TO APP


Future<void> showCallFinishedDialog(BuildContext context , String name, [documentDataAtIndex]) async {
  // Start the timer when the dialog is shown
  // _startCallTimer(setState); // Start the timer

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
                Text('Elapsed Time: $elapsedSeconds seconds'),
                const SizedBox(height: 20),
                Text('Call: ' +  name), // Display the parameter text in the dialog
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                     int index1 = 0;   
                          Map<String, dynamic> documentDataAtIndex0 = getDocumentByIndex(index1);
        
                makePhoneCall(({documentDataAtIndex0['contact_phone_number']}).toString());  
                  index1 = index1 + 1;
                  setState(() {
                    elapsedSeconds = 0; // Reset the counter
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






// Dropdown
  
  






Future<void> fetchDataFromFirestore() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('lists_collection').get();
      

      // setState(() {
      //   list = querySnapshot.docs.map((doc) => doc['list_name'] as String).toList();

       // If the list is not empty, set the dropdown value to the first item
      //   if (list.isNotEmpty) {
      //     dropdownValue = list.first;
      //   }
      // });
    } catch (error) {
      print("Error fetching data: $error");
    }
  }









class functions extends StatefulWidget {
  const functions({super.key});

  @override
  State<functions> createState() => _functionsState();
}

class _functionsState extends State<functions> {









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



Future<void> fetchDataFromFirestore() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('lists_collection').where('userId', isEqualTo: userId).get();

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









// Dropdown


  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}



    String getCurrentScreen(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route != null) {
      return route.settings.name ?? '';
    }
    return '';
  }



//  Widget buildBottomNavigationBar(context) {
//     return Container(
//         color: Colors.black,
//         child: Padding(
//           padding: const  EdgeInsets.symmetric(
//             horizontal: 15.0,
//             vertical: 20,
//             ),
//           child: GNav(
//                   backgroundColor: Colors.black,
//                   color: Colors.white,
//                   activeColor: Colors.white,
//                   tabBackgroundColor: Colors.grey.shade800,
//                   padding: EdgeInsets.all(16),
                  
//                   onTabChange: (pageindex) {
//                     print(pageindex);

//                       if (pageindex == 0) {
//                       Navigator.of(context).push(
//                         MaterialPageRoute(
//                           builder: (context) =>  NotesView(),
//                         ),
//                       );
                      
//                     }



//                       if (pageindex == 1) {
//                       Navigator.of(context).push(
//                         MaterialPageRoute(
//                           builder: (context) =>  ListScreen(),
//                         ),
//                       );
                      
//                     }


//                     if (pageindex  == 2) {
//                       Navigator.of(context).push(
//                         MaterialPageRoute(
//                           builder: (context) =>  DialerView(),
//                         ),
//                       );
                      
//                     }

//                   if (pageindex  == 3) {
//                       Navigator.of(context).push(
//                         MaterialPageRoute(
//                           builder: (context) => ReportsView(),
//                         ),
//                       );

                      
//                     }


//                     final currentScreen = getCurrentScreen(context);
//                     print(currentScreen);
//                   },

                  
//                   // rippleColor: Colors.grey[300]!,
//                   // hoverColor: Colors.grey[100]!,
//                   // gap: 8,
//                   // activeColor: Colors.black,
//                   // iconSize: 24,
//                   // //padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//                   // duration: Duration(milliseconds: 400),
//                   // tabBackgroundColor: Colors.grey[100]!,
//                   // color: Colors.black,
//                   haptic: true,
//             tabs: const[
//               GButton(
//                 icon: Icons.home,
//                 text: 'Home',
//                 ),
//               GButton(
//                 icon: Icons.list,
//                 text: 'List',
//                 ),
//               GButton(
//                 icon: Icons.call,
//                 text: 'Dialer',
//                 ),
//                 GButton(
//                 icon: Icons.bar_chart,
//                 text: 'Reports',
//                 ),
//               GButton(
//                 icon: Icons.settings,
//                 text: 'Settigns',
//               ),
//             ],

            
            
//           ),
//         ),
//     );
//   }





















class Gbar extends StatefulWidget {
  const Gbar({super.key});

  @override
  State<Gbar> createState() => _GbarState();
}

class _GbarState extends State<Gbar> {



  @override
  Widget build(BuildContext context) {
    return Container(
        color: Colors.black,
        child: Padding(
          padding: const  EdgeInsets.symmetric(
            horizontal: 15.0,
            vertical: 20,
            ),
          child: GNav(
                  backgroundColor: Colors.black,
                  color: Colors.white,
                  activeColor: Colors.white,
                  tabBackgroundColor: Colors.grey.shade800,
                  padding: EdgeInsets.all(16),
                  
                  onTabChange: (pageindex) {
                    print(pageindex);







                    //   if (pageindex == 0) {
                    //   Navigator.of(context).push(
                    //     MaterialPageRoute(
                    //       builder: (context) =>  ListScreen(),
                    //     ),
                    //   );
                      
                    // }

                if (pageindex == 0) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>  list_view_visible(),
                        ),
                      );
                      
                    }


                    if (pageindex  == 1) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => DialerContactsView(listName: selectedList,),
                        ),
                      );
                      
                    }

                  if (pageindex  == 2) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ReportsView(),
                        ),
                      );
                    }


                    final currentScreen = getCurrentScreen(context);
                    print(currentScreen);
                  },

                  
                  // rippleColor: Colors.grey[300]!,
                  // hoverColor: Colors.grey[100]!,
                  // gap: 8,
                  // activeColor: Colors.black,
                  // iconSize: 24,
                  // //padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  // duration: Duration(milliseconds: 400),
                  // tabBackgroundColor: Colors.grey[100]!,
                  // color: Colors.black,
                  haptic: true,
            tabs: const[
              // GButton(
              //   icon: Icons.home,
              //   text: 'Home',
              //   ),
              GButton(
                icon: Icons.list,
                text: 'List',
                ),
              GButton(
                icon: Icons.call,
                text: 'Dialer',
                ),
                GButton(
                icon: Icons.bar_chart,
                text: 'Reports',
                ),
              // GButton(
              //   icon: Icons.settings,
              //   text: 'Settigns',
              // ),
            ],

            
            
          ),
        ),
    );
  }

}






  Color textColor(BuildContext context) {
   
      return Colors.black;
    
  }
