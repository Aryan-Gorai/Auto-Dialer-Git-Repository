// Central Firestore helper file — contains all the shared functions used
// across list views, the dialer, and onboarding. Handles:
//   - Phone number normalisation (last 9 digits for deduplication)
//   - Adding/removing contacts to/from the normalised Contact Directories
//   - Creating/deleting lists in lists_collection
//   - Building the bottom navigation bar (Gbar widget)
//   - Global state variables (selectedList, kPickedName, etc.)
// Basically the "service layer" that sits between the UI and Firestore.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bloc/bloc.dart';

import 'package:flutter/material.dart';

import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:flutter_application_1/utilities/dialogs/error_dialog.dart';

//import 'package:flutter_application_1/views/dialer/dialer.dart';
// import 'package:flutter_application_1/views/dialer/dialer_backup.dart';
import 'package:flutter_application_1/views/list/list_view.dart';
import 'package:flutter_application_1/views/list/list_view_visible.dart';
import 'package:flutter_application_1/views/notes/contact_notes_view.dart';
import 'package:flutter_application_1/views/onBoarding/onBoarding.dart';
// import 'package:flutter_application_1/views/profile/user_profile_editor.dart';
import 'package:flutter_application_1/views/reports/reports_view_clean.dart';
import 'package:fluttercontactpicker/fluttercontactpicker.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:google_nav_bar/google_nav_bar.dart';

import 'package:url_launcher/url_launcher.dart';
import 'dart:async';



 bool hasCallSupport = false;
 Future<void>? launched;
 String phone = '';
 String selectedList = '';
 
  List<String> listNames = []; // To store the list names from Firestore

String get userId => AuthService.firebase().currentUser!.id;

// Firestore collection for contact directory (per user, de-duplicated)
const String contactDirectoriesCollection = 'Contact Directories';

String kPickedNumber = '';
String kPickedName = '';
PhoneContact? phoneContact;

// ============================================================================
// NORMALIZED DATABASE HELPER FUNCTIONS
// All contact data is now stored in "Contact Directories" with list_memberships
// The old "lists" collection is deprecated
// ============================================================================

/// Normalize a phone number for consistent deduping (last 9 digits only)
/// This handles cases like +44 7845967135 vs 07845967135
String normalizePhone(String input) {
  final digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.length >= 9) {
    return digitsOnly.substring(digitsOnly.length - 9);
  }
  return digitsOnly; // Return as-is if less than 9 digits
}

/// Get the document ID for a contact in Contact Directories
String getContactDocId(String phoneNumber) {
  return '${userId}_${normalizePhone(phoneNumber)}';
}

/// Add or update a contact in Contact Directories with list membership and index
Future<void> addContactToList({
  required String contactName,
  required String contactPhoneNumber,
  required String listName,
  int? contactIndex,
}) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final normalizedPhoneNum = normalizePhone(contactPhoneNumber);
    final docId = '${userId}_$normalizedPhoneNum';
    final docRef = firestore.collection(contactDirectoriesCollection).doc(docId);

    final existing = await docRef.get();
    final now = FieldValue.serverTimestamp();

    // Calculate the contact index if not provided
    int indexToUse = contactIndex ?? await getNextContactIndexForList(listName);

    if (existing.exists) {
      // Get existing list_memberships
      final data = existing.data()!;
      Map<String, dynamic> listMemberships = 
          Map<String, dynamic>.from(data['list_memberships'] ?? {});
      
      // Add or update this list membership with index
      listMemberships[listName] = {'contact_index': indexToUse};

      await docRef.update({
        'contact_name': contactName,
        'contact_phone_number': contactPhoneNumber,
        'normalized_phone': normalizedPhoneNum,
        'list_memberships': listMemberships,
        'updated_at': now,
      });
    } else {
      // Create new directory entry
      await docRef.set({
        'contact_name': contactName,
        'contact_phone_number': contactPhoneNumber,
        'normalized_phone': normalizedPhoneNum,
        'user_id': userId,
        'list_memberships': {
          listName: {'contact_index': indexToUse}
        },
        'created_at': now,
        'updated_at': now,
      });
    }
    print('✅ Contact added/updated in directory: $contactName for list: $listName at index: $indexToUse');
  } catch (e) {
    print('❌ Error adding contact to directory: $e');
    rethrow;
  }
}

/// Get the next available contact index for a list
Future<int> getNextContactIndexForList(String listName) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore
        .collection(contactDirectoriesCollection)
        .where('user_id', isEqualTo: userId)
        .get();

    int maxIndex = -1;
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final memberships = data['list_memberships'] as Map<String, dynamic>?;
      if (memberships != null && memberships.containsKey(listName)) {
        final listData = memberships[listName] as Map<String, dynamic>;
        final idx = listData['contact_index'] as int? ?? 0;
        if (idx > maxIndex) maxIndex = idx;
      }
    }
    return maxIndex + 1;
  } catch (e) {
    print('Error getting next index: $e');
    return 0;
  }
}

/// Remove a contact from a specific list (keeps the contact in directory if in other lists)
Future<void> removeContactFromList({
  required String contactPhoneNumber,
  required String listName,
}) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final normalizedPhoneNum = normalizePhone(contactPhoneNumber);
    final docId = '${userId}_$normalizedPhoneNum';
    final docRef = firestore.collection(contactDirectoriesCollection).doc(docId);

    final existing = await docRef.get();
    if (!existing.exists) return;

    final data = existing.data()!;
    Map<String, dynamic> listMemberships = 
        Map<String, dynamic>.from(data['list_memberships'] ?? {});
    
    // Remove this list from memberships
    listMemberships.remove(listName);

    if (listMemberships.isEmpty) {
      // No more list memberships - optionally delete the contact entirely
      // For now, keep it in directory but with empty memberships
      await docRef.update({
        'list_memberships': {},
        'updated_at': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.update({
        'list_memberships': listMemberships,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
    print('✅ Removed contact from list: $listName');
  } catch (e) {
    print('❌ Error removing contact from list: $e');
  }
}

/// Fetch all contacts for a specific list, sorted by contact_index
Future<List<Map<String, dynamic>>> fetchContactsForList(String listName) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore
        .collection(contactDirectoriesCollection)
        .where('user_id', isEqualTo: userId)
        .get();

    List<Map<String, dynamic>> contacts = [];
    
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final memberships = data['list_memberships'] as Map<String, dynamic>?;
      
      if (memberships != null && memberships.containsKey(listName)) {
        final listData = memberships[listName] as Map<String, dynamic>;
        contacts.add({
          'doc_id': doc.id,
          'contact_name': data['contact_name'] ?? '',
          'contact_phone_number': data['contact_phone_number'] ?? '',
          'normalized_phone': data['normalized_phone'] ?? '',
          'contact_index': listData['contact_index'] ?? 0,
          'list_memberships': memberships,
        });
      }
    }

    // Sort by contact_index
    contacts.sort((a, b) => 
        (a['contact_index'] as int).compareTo(b['contact_index'] as int));

    return contacts;
  } catch (e) {
    print('❌ Error fetching contacts for list: $e');
    return [];
  }
}

/// Get contact names as array for a list (for display purposes)
Future<List<String>> fetchContactNamesForList(String listName) async {
  final contacts = await fetchContactsForList(listName);
  return contacts.map((c) => c['contact_name'] as String).toList();
}

/// Update contact indices after reordering
Future<void> updateContactIndicesForList(String listName, List<String> orderedContactNames) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    
    // Fetch all contacts in this list
    final contacts = await fetchContactsForList(listName);
    
    for (int i = 0; i < orderedContactNames.length; i++) {
      final contactName = orderedContactNames[i];
      final contact = contacts.firstWhere(
        (c) => c['contact_name'] == contactName,
        orElse: () => {},
      );
      
      if (contact.isNotEmpty) {
        final docRef = firestore.collection(contactDirectoriesCollection).doc(contact['doc_id']);
        Map<String, dynamic> memberships = Map<String, dynamic>.from(contact['list_memberships']);
        memberships[listName] = {'contact_index': i};
        
        batch.update(docRef, {
          'list_memberships': memberships,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    }
    
    await batch.commit();
    print('✅ Updated indices for ${orderedContactNames.length} contacts in $listName');
  } catch (e) {
    print('❌ Error updating contact indices: $e');
  }
}

/// Get contact count for a list
Future<int> getContactCountForList(String listName) async {
  final contacts = await fetchContactsForList(listName);
  return contacts.length;
}

/// Delete all contacts from a list (removes list membership, not the contacts themselves)
Future<void> deleteAllContactsFromList(String listName) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final contacts = await fetchContactsForList(listName);
    
    final batch = firestore.batch();
    for (var contact in contacts) {
      final docRef = firestore.collection(contactDirectoriesCollection).doc(contact['doc_id']);
      Map<String, dynamic> memberships = Map<String, dynamic>.from(contact['list_memberships']);
      memberships.remove(listName);
      
      batch.update(docRef, {
        'list_memberships': memberships,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    print('✅ Removed all contacts from list: $listName');
  } catch (e) {
    print('❌ Error deleting contacts from list: $e');
  }
}

// ============================================================================
// END NORMALIZED DATABASE HELPER FUNCTIONS
// ============================================================================

// ============================================================================
// DATA MIGRATION HELPER
// Run this once to migrate existing data from 'lists' collection to Contact Directories
// ============================================================================

/// Migrate existing contacts from the old 'lists' collection to Contact Directories
/// This should be run once per user to migrate their existing data
Future<void> migrateListsToContactDirectories() async {
  try {
    print('🔄 Starting migration from lists to Contact Directories...');
    final firestore = FirebaseFirestore.instance;
    
    // Fetch all contacts from old lists collection for this user
    final oldListsSnapshot = await firestore
        .collection('lists')
        .where('user_id', isEqualTo: userId)
        .get();
    
    if (oldListsSnapshot.docs.isEmpty) {
      print('✅ No data to migrate - lists collection is empty');
      return;
    }
    
    print('📊 Found ${oldListsSnapshot.docs.length} contacts in old lists collection');
    
    // Group contacts by normalized phone number to handle duplicates
    Map<String, Map<String, dynamic>> contactsByPhone = {};
    
    for (var doc in oldListsSnapshot.docs) {
      final data = doc.data();
      final phoneNumber = data['contact_phone_number'] as String? ?? '';
      final contactName = data['contact_name'] as String? ?? '';
      final listName = data['list_name'] as String? ?? '';
      final contactIndex = data['contact_index'] as int? ?? 0;
      
      if (phoneNumber.isEmpty) continue;
      
      final normalizedPhoneNum = normalizePhone(phoneNumber);
      final docId = '${userId}_$normalizedPhoneNum';
      
      if (contactsByPhone.containsKey(docId)) {
        // Add list membership to existing contact
        Map<String, dynamic> memberships = contactsByPhone[docId]!['list_memberships'];
        memberships[listName] = {'contact_index': contactIndex};
      } else {
        // Create new contact entry
        contactsByPhone[docId] = {
          'contact_name': contactName,
          'contact_phone_number': phoneNumber,
          'normalized_phone': normalizedPhoneNum,
          'user_id': userId,
          'list_memberships': {
            listName: {'contact_index': contactIndex}
          },
        };
      }
    }
    
    print('📊 Consolidated to ${contactsByPhone.length} unique contacts');
    
    // Write migrated data to Contact Directories
    final batch = firestore.batch();
    final now = FieldValue.serverTimestamp();
    
    for (var entry in contactsByPhone.entries) {
      final docRef = firestore.collection(contactDirectoriesCollection).doc(entry.key);
      
      // Check if document already exists
      final existing = await docRef.get();
      
      if (existing.exists) {
        // Merge with existing data
        final existingData = existing.data()!;
        Map<String, dynamic> existingMemberships = 
            Map<String, dynamic>.from(existingData['list_memberships'] ?? {});
        
        // Merge new memberships
        final newMemberships = entry.value['list_memberships'] as Map<String, dynamic>;
        existingMemberships.addAll(newMemberships);
        
        batch.update(docRef, {
          'list_memberships': existingMemberships,
          'updated_at': now,
        });
      } else {
        // Create new document
        batch.set(docRef, {
          ...entry.value,
          'created_at': now,
          'updated_at': now,
        });
      }
    }
    
    await batch.commit();
    print('✅ Migration complete! ${contactsByPhone.length} contacts migrated to Contact Directories');
    
  } catch (e) {
    print('❌ Error during migration: $e');
    rethrow;
  }
}

/// Check if migration is needed (old lists collection has data, new structure doesn't)
Future<bool> needsMigration() async {
  try {
    final firestore = FirebaseFirestore.instance;
    
    // Check if old lists collection has data
    final oldListsSnapshot = await firestore
        .collection('lists')
        .where('user_id', isEqualTo: userId)
        .limit(1)
        .get();
    
    if (oldListsSnapshot.docs.isEmpty) {
      return false; // No old data to migrate
    }
    
    // Check if any Contact Directory has list_memberships field
    final newContactsSnapshot = await firestore
        .collection(contactDirectoriesCollection)
        .where('user_id', isEqualTo: userId)
        .limit(1)
        .get();
    
    if (newContactsSnapshot.docs.isEmpty) {
      return true; // Old data exists but no new data
    }
    
    // Check if the first doc has list_memberships
    final firstDoc = newContactsSnapshot.docs.first.data();
    return firstDoc['list_memberships'] == null;
    
  } catch (e) {
    print('Error checking migration status: $e');
    return false;
  }
}

// ============================================================================
// END DATA MIGRATION HELPER
// ============================================================================

// Simple BLoC that loads list names from Firestore and emits them as state.
// Used by dropdown widgets to keep the list picker in sync.
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



// Wrapper that takes the globally-picked contact name/number and
// saves it into Contact Directories under the current listName.
Future<void> addNewContactData() async {
 try {
   // Use the new normalized Contact Directories structure
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




// Creates a brand-new list document in lists_collection.
// Stores the list name, owner user_id, initial index/doc count,
// and a server timestamp so we can sort lists by creation order.
Future<void> addNewList(String listName) async {
  try {
    // Get the Firestore instance
    FirebaseFirestore firestore = FirebaseFirestore.instance;

    // Create a reference to the 'lists_collection' collection
    CollectionReference listsRef = firestore.collection('lists_collection');
    fetchDataFromFirestore();

    // Create a map with the new list data
    // Use timestamp to track creation order - newer lists will have higher values
    Map<String, dynamic> newListData = {
      'list_name': listName,
      'user_id': userId,
      'current_index': index,
      'total_documents': totalDocuments,
      'description': '',
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






  


 PhoneContact? _phoneContact;
// Handles the "upload a single contact" button tap in the dialer contacts view.
// Requests contacts permission, opens the native picker, validates the result,
// and writes the contact to the selected list in Contact Directories.
Future<void> upload_button_on_dialer_contacts_view(BuildContext context, String selectedList) async {
  try {
    bool permission = await FlutterContactPicker.requestPermission();
    if (!permission) {
      await showErrorDialog(context, 'Contact permission denied');
      return;
    }

    if (!await FlutterContactPicker.hasPermission()) {
      await showErrorDialog(context, 'No contact access permission');
      return;
    }

    _phoneContact = await FlutterContactPicker.pickPhoneContact();
    if (_phoneContact == null) {
      return; // User cancelled contact picker
    }

    if (_phoneContact!.fullName == null || _phoneContact!.fullName!.isEmpty) {
      await showErrorDialog(context, 'Contact has no name');
      return;
    }

    if (_phoneContact!.phoneNumber == null || _phoneContact!.phoneNumber!.number!.isEmpty) {
      await showErrorDialog(context, 'Contact has no phone number');
      return;
    }

    kPickedName = _phoneContact!.fullName.toString();
    kPickedNumber = _phoneContact!.phoneNumber!.number.toString();

    if (selectedList.isEmpty) {
      await showErrorDialog(context, 'Please select a list first');
      return;
    }

    await addNewContactDataToList(selectedList);
    // List will automatically refresh via the fetchContactsAsArray call
  } catch (e) {
    await showErrorDialog(context, 'Failed to upload contact: ${e.toString()}');
  }
}

/// Simple contact data class to avoid holding heavy Contact objects
class SimpleContact {
  final String id;
  final String displayName;
  final String phoneNumber;

  SimpleContact({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
  });
}

// Bulk-upload flow: loads ALL device contacts in memory-friendly batches,
// presents a searchable multi-select dialog (MultiContactSelectDialog),
// then writes every selected contact to Contact Directories for the chosen list.
Future<int> uploadMultipleContacts(BuildContext context, String selectedList) async {
  try {
    // Request permission using flutter_contacts
    bool permission = await fc.FlutterContacts.requestPermission();
    if (!permission) {
      if (context.mounted) {
        await showErrorDialog(context, 'Contact permission denied');
      }
      return 0;
    }

    if (selectedList.isEmpty) {
      if (context.mounted) {
        await showErrorDialog(context, 'Please select a list first');
      }
      return 0;
    }

    // Show loading dialog while fetching contacts
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text('Loading contacts...'),
                ],
              ),
            ),
          );
        },
      );
    }

    List<SimpleContact> simpleContacts = [];
    
    try {
      // First get all contact IDs without properties (lightweight)
      List<fc.Contact> lightContacts = await fc.FlutterContacts.getContacts(
        withProperties: false,
        withPhoto: false,
      );

      // Process contacts in batches to avoid memory pressure
      const int batchSize = 50;
      for (int i = 0; i < lightContacts.length; i += batchSize) {
        int end = (i + batchSize < lightContacts.length) ? i + batchSize : lightContacts.length;
        List<fc.Contact> batch = lightContacts.sublist(i, end);
        
        for (fc.Contact lightContact in batch) {
          try {
            // Fetch full contact details one at a time
            fc.Contact? fullContact = await fc.FlutterContacts.getContact(lightContact.id);
            if (fullContact != null && fullContact.phones.isNotEmpty) {
              simpleContacts.add(SimpleContact(
                id: fullContact.id,
                displayName: fullContact.displayName,
                phoneNumber: fullContact.phones.first.number,
              ));
            }
          } catch (e) {
            // Skip contacts that fail to load
            continue;
          }
        }
        
        // Small delay between batches to reduce memory pressure
        await Future.delayed(Duration(milliseconds: 10));
      }
    } catch (e) {
      print('Error loading contacts: $e');
    }

    // Dismiss loading dialog
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (simpleContacts.isEmpty) {
      if (context.mounted) {
        await showErrorDialog(context, 'No contacts with phone numbers found');
      }
      return 0;
    }

    // Show multi-select dialog
    List<SimpleContact>? selectedContacts;
    if (context.mounted) {
      selectedContacts = await showDialog<List<SimpleContact>>(
        context: context,
        builder: (BuildContext context) {
          return MultiContactSelectDialog(contacts: simpleContacts);
        },
      );
    }

    if (selectedContacts == null || selectedContacts.isEmpty) {
      return 0; // User cancelled or selected nothing
    }

    // Show progress while adding contacts
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text('Adding ${selectedContacts!.length} contacts...'),
                ],
              ),
            ),
          );
        },
      );
    }

    // Add all selected contacts to the list
    int addedCount = 0;
    for (SimpleContact contact in selectedContacts) {
      if (contact.displayName.isNotEmpty && contact.phoneNumber.isNotEmpty) {
        await addContactToList(
          contactName: contact.displayName,
          contactPhoneNumber: contact.phoneNumber,
          listName: selectedList,
        );
        addedCount++;
      }
    }

    // Dismiss progress dialog
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    return addedCount;
  } catch (e) {
    // Dismiss any open dialogs
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      await showErrorDialog(context, 'Failed to upload contacts: ${e.toString()}');
    }
    return 0;
  }
}

// Full-screen dialog with a search bar and select-all/deselect-all buttons.
// Lets the user tick contacts from their phonebook before bulk-uploading.
class MultiContactSelectDialog extends StatefulWidget {
  final List<SimpleContact> contacts;

  const MultiContactSelectDialog({Key? key, required this.contacts}) : super(key: key);

  @override
  State<MultiContactSelectDialog> createState() => _MultiContactSelectDialogState();
}

class _MultiContactSelectDialogState extends State<MultiContactSelectDialog> {
  final Set<SimpleContact> _selectedContacts = {};
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<SimpleContact> get _filteredContacts {
    if (_searchQuery.isEmpty) {
      return widget.contacts;
    }
    final query = _searchQuery.toLowerCase();
    return widget.contacts.where((contact) {
      return contact.displayName.toLowerCase().contains(query) ||
          contact.phoneNumber.contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Contacts',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_selectedContacts.length} selected',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Search bar
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search contacts...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            // Select All / Deselect All buttons
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedContacts.addAll(_filteredContacts);
                      });
                    },
                    icon: Icon(Icons.select_all, size: 18),
                    label: Text('Select All'),
                  ),
                  SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedContacts.clear();
                      });
                    },
                    icon: Icon(Icons.deselect, size: 18),
                    label: Text('Deselect All'),
                  ),
                ],
              ),
            ),
            // Contact list
            Expanded(
              child: ListView.builder(
                itemCount: _filteredContacts.length,
                itemBuilder: (context, index) {
                  final contact = _filteredContacts[index];
                  final isSelected = _selectedContacts.contains(contact);

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedContacts.add(contact);
                        } else {
                          _selectedContacts.remove(contact);
                        }
                      });
                    },
                    title: Text(
                      contact.displayName,
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      contact.phoneNumber,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    secondary: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      child: Text(
                        contact.displayName.isNotEmpty 
                            ? contact.displayName[0].toUpperCase() 
                            : '?',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    activeColor: Theme.of(context).colorScheme.primary,
                    checkColor: Colors.white,
                  );
                },
              ),
            ),
            // Action buttons
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedContacts.isEmpty
                          ? null
                          : () => Navigator.of(context).pop(_selectedContacts.toList()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Add ${_selectedContacts.length} Contact${_selectedContacts.length == 1 ? '' : 's'}'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// Shows a simple dialog that creates a new list, then jumps to page 1
// of the intro slider. Called from the onboarding flow.
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.list_alt, color: Theme.of(context).colorScheme.primary, size: 22),
            const SizedBox(width: 8),
            const Text('Create list', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ],
        ),
        content: TextField(
          controller: listNameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter list name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Create'),
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











  Future<void> updateListDescription(String listName, String description) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot snapshot = await firestore
          .collection('lists_collection')
          .where('list_name', isEqualTo: listName)
          .where('user_id', isEqualTo: userId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        DocumentReference docRef = snapshot.docs.first.reference;
        await docRef.update({
          'description': description,
        });
        print('Description updated for $listName');
      }
    } catch (e) {
      print('Error updating description: $e');
    }
  }

  Future<void> addNewContactDataToList(selectedList) async {
    try {
      if (selectedList.isEmpty) {
        print('Please Upload Contacts.');
        return;
      }

      // Use the new normalized Contact Directories structure
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
    listNames = names;
    // setState(() {
    //   listNames = names;
    // });
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

Future<void> fetchDocumentAtIndexAndShowDialog(BuildContext context, int index, selectedList) async {
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
      context,
      contact['contact_name'],
      contact['contact_phone_number'],
      "Not available", // call_duration is tracked in contact_notes now
    );
    print(index);
  } else {
    print('Invalid index. Document not found.');
    print(index);

    await showErrorDialog(context, 'Contact not found, reset index, or upload contacts, or select a list from the dropdown');
  }
}








// CODE TO DISPLAY CONTACTS NAME IN LISTS



// CODE TO DISPLAY CONTACTS NAME IN LISTS
















//int index = 0; // DEFINITION OF CALL CYCLE INDEX

// Main call-cycle dialog — shows contact info, records a call timestamp,
// auto-dials after 5 seconds, and offers Next / Close / View Notes actions.
Future<void> showContactDialog(BuildContext context, String contactName, String contactPhoneNumber, String callDuration) async {
  // Record call timestamp in Firebase
  await recordCallTimestamp(contactName, contactPhoneNumber, selectedList);
  
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
            },
            child: const Text('Next'),
          ),
          TextButton(
            onPressed: () async  {
              // Perform any action you want when the user clicks a button
              Navigator.of(context).pop();
              // CODE HERE TO UPDATE TO FIREBASE THE TOTAL DOCUMENTS AND CURRENT INDEX NUMBER

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
          TextButton(
            onPressed: () {
              // Navigate to notes page for this contact
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ContactNotesView(
                    contactName: contactName,
                    contactPhoneNumber: contactPhoneNumber,
                    listName: selectedList,
                  ),
                ),
              );
            },
            child: const Text('View Notes'),
          ),
        ],
      );
    },
  );

  await Future.delayed(Duration(seconds: 5));
  makePhoneCall(contactPhoneNumber);
}

// Writes a document to 'contact_notes' each time a call is initiated.
// This acts as the call log and enables the reports/analytics views
// to calculate daily/weekly call volumes and response rates.
Future<void> recordCallTimestamp(String contactName, String contactPhoneNumber, String listName) async {
  try {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    CollectionReference callLogsRef = firestore.collection('contact_notes');
    
    // Create a timestamp for the current time
    Timestamp timestamp = Timestamp.now();
    
    print('Recording call timestamp for: $contactName, Phone: $contactPhoneNumber, List: $listName, UserID: $userId');
    
    // Create a map with the call log data
    Map<String, dynamic> callLogData = {
      'user_id': userId,
      'contact_name': contactName,
      'contact_phone_number': contactPhoneNumber,
      'list_name': listName,
      'timestamp': timestamp,
      'note_text': 'Call initiated', // Default note text
      'rating': 0, // Initialize rating to 0
      'has_feedback': false, // Mark as not having feedback yet
    };
    
    // Add the new document with an auto-generated ID
    DocumentReference newDoc = await callLogsRef.add(callLogData);
    
    print('✅ Call timestamp recorded successfully! Doc ID: ${newDoc.id}');
  } catch (e) {
    print('❌ Error recording call timestamp: $e');
  }
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





// TO TRY AND CYCLE THROUGH THE DATA (using new Contact Directories structure)


Future<void> cycleThroughContacts() async {
  // Use the new Contact Directories structure
  final contacts = await fetchContactsForList(selectedList);

  // Iterate through the contacts
  for (var contact in contacts) {
    print('Contact Name: ${contact['contact_name']}');
    print('Contact Phone Number: ${contact['contact_phone_number']}');
    print('User ID: $userId');
    print('Contact Index: ${contact['contact_index']}');

    // Here you can perform any logic or operations on the contact
    // For example, you can wait for the user to call the contact
  }
}








// TO TRY AND CYCLE THROUGH THE DATA








Timer? callTimer;
 int elapsedSeconds = 0;






// Kicks off a 1-second periodic timer that increments elapsedSeconds.
// Used by the call-finished dialog to show how long the call lasted.
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




 // ignore: unused_element
 void _stopTimer() {
   callTimer?.cancel();
 }








// DIALOG WHEN USER RETURNS TO APP


// Pops up when the user returns to the app after a phone call.
// Shows elapsed time and gives the option to redial or dismiss.
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
  await FirebaseFirestore.instance.collection('lists_collection').get();
      

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





















// Legacy bottom navigation bar using GNav — replaced by the liquid-glass
// tab bar in sliderScreen.dart, but kept here for backwards compatibility.
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
