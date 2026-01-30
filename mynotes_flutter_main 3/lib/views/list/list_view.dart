


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
import 'package:flutter_application_1/views/reports/reports_view.dart';
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
                'list_order': FieldValue.serverTimestamp(), // Add timestamp for ordering
                'created_at': FieldValue.serverTimestamp(), // Track creation time
              };

              // Add the new document with an auto-generated ID
              await listsRef.add(newListData);

              fetchDataFromFirestore();
              
            // fetchContactsAsArray(selectedList);




 }



 Future<void>  DeleteAllContactsButtonFunction() async {
        // Use the new Contact Directories structure
        // This removes all list memberships for the current user's lists
        FirebaseFirestore firestore = FirebaseFirestore.instance;
        CollectionReference listsCollectionRef = firestore.collection('lists_collection');
        
        // Get all lists for this user
        QuerySnapshot listsSnapshot = await listsCollectionRef
            .where('user_id', isEqualTo: userId)
            .get();
        
        // Delete contacts from each list
        for (var listDoc in listsSnapshot.docs) {
          String listName = listDoc['list_name'];
          await deleteAllContactsFromList(listName);
        }

        fetchDataFromFirestore();
 }


Future<void> DeleteAllContactsFromListButtonFunction() async {
  // Use the new Contact Directories structure
  await deleteAllContactsFromList(selectedList);
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
      'list_order': FieldValue.serverTimestamp(), // Add timestamp for ordering
      'created_at': FieldValue.serverTimestamp(), // Track creation time
    };

    // Add the new document with an auto-generated ID
    await listsRef.add(newListData);

    // I can perform any additional actions after creating the list here.

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

 // Helper method to fetch contacts and update display
 Future<void> fetchContactsAsArray(String listToFetch) async {
   final contacts = await fetchContactsForList(listToFetch);
   final names = contacts.map((c) => c['contact_name'] as String).toList();
   listContactsJoined = names.join(", ");
   listContactsJoinedforDialerView = listContactsJoined;
   if (mounted) setState(() {});
 }

 @override
 void initState() {
   super.initState();

    fetchContactsAsArray(selectedList);

   getListNames();



   
   fetchDataFromFirestore();
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














// CODE TO MAKE A NEW DOCUMENT EACH TIME


Future<void> addNewContactData() async {
 try {
   // Use the new Contact Directories structure
   await addContactToList(
     contactName: kPickedName,
     contactPhoneNumber: kPickedNumber,
     listName: listName,
   );
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
      'list_order': FieldValue.serverTimestamp(), // Add timestamp for ordering
      'created_at': FieldValue.serverTimestamp(), // Track creation time
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

      // Use the new Contact Directories structure
      await addContactToList(
        contactName: kPickedName,
        contactPhoneNumber: kPickedNumber,
        listName: selectedList,
      );
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







// TO READ DATA (using new Contact Directories structure)




void fetchDocumentsInOrder() async {
  // Fetch contacts from Contact Directories for the selected list
  final contacts = await fetchContactsForList(selectedList);
  
  for (var contact in contacts) {
    print('Contact Name: ${contact['contact_name']}');
    print('Contact Phone Number: ${contact['contact_phone_number']}');
    print('User ID: $userId');
    print('Contact Index: ${contact['contact_index']}');
  }
}





int totalDocuments = 0; 

Future<void> fetchDocumentAtIndexAndShowDialog(int index, selectedList) async {
  // Use the new Contact Directories structure
  final contacts = await fetchContactsForList(selectedList);
  totalDocuments = contacts.length;

  print('Total number of documents: $totalDocuments');

  if (index >= 0 && index < contacts.length) {
    final contact = contacts[index];

    print('Contact Name: ${contact['contact_name']}');
    print('Contact Phone Number: ${contact['contact_phone_number']}');
    print('Contact Index: ${contact['contact_index']}');

    // Call the dialog function after fetching the document
    showContactDialog(
      contact['contact_name'],
      contact['contact_phone_number'],
      "Not available", // call_duration is tracked in contact_notes now
    );
    print(index);
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

void fetchDocumentsInOrderAndSaveToArray() async {
  // Use the new Contact Directories structure
  documentArray = await fetchContactsForList(selectedList);
  index++;
}

// Function to access the document data through the index array (top-level helper)
Map<String, dynamic> getDocumentByIndex(int index) {
  if (index >= 0 && index < documentArray.length) {
    print(documentArray[index]);
    return documentArray[index];
  } else {
    return {};
  }
}

// cycleThroughContacts is available from firebase_services.dart

// Top-level variable for contact display
String listContactsJoined = "";

// Dropdown









 @override
 Widget build(BuildContext context) {
   //final Uri toLaunch = Uri(scheme: 'https', host: 'www.mavenswood.com');


   return Scaffold(



     backgroundColor: const Color.fromRGBO(248, 225, 209, 1), 



     appBar: AppBar(
       title: const Text('List Builder View'),
       centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
             fetchDataFromFirestore();
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
                                
                             
                              await fetchDataFromFirestore();
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
  onPressed: () async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => list_view_visible(),
      ),
    );
    
    if (result == true) {
      // Refresh data when returning from DialerContactsView
      await fetchDataFromFirestore();
      await fetchContactsAsArray(selectedList);
    }
  },
  child: Text('View Contacts'),
),
















          //  ],   
        //  ),


       ],
     ),










   );
 }
}



bool isLoading = true;
