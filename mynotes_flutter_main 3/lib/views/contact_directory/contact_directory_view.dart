// Unified contact directory — shows every contact the user has ever added
// across all lists, de-duplicated by normalised phone number. Supports
// searching, importing from phone contacts or Excel, viewing which lists a
// contact belongs to, and navigating to the Naive Bayes call prediction page.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter_application_1/utilities/apple_typography.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:flutter_application_1/services/excel_import_service.dart';
import 'package:flutter_application_1/views/contact_directory/call_prediction_view.dart';
import 'package:flutter_application_1/views/list/firebase_services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;

class ContactDirectoryView extends StatefulWidget {
  const ContactDirectoryView({Key? key}) : super(key: key);

  @override
  State<ContactDirectoryView> createState() => _ContactDirectoryViewState();
}

class _ContactDirectoryViewState extends State<ContactDirectoryView> {
  List<Map<String, dynamic>> contacts = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  String get userId => AuthService.firebase().currentUser!.id;

  @override
  void initState() {
    super.initState();
    // Use post-frame callback to ensure widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchContacts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Pulls every contact doc for this user from 'Contact Directories'.
  // Handles both the old flat 'lists' array and the new 'list_memberships'
  // map structure, then sorts alphabetically and updates local state.
  Future<void> _fetchContacts() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Contact Directories')
          .where('user_id', isEqualTo: userId)
          .get();

      final fetchedContacts = snapshot.docs.map((doc) {
        final data = doc.data();
        
        // Get list names from list_memberships (new structure) or lists (old structure)
        List<String> listNames = [];
        if (data['list_memberships'] != null) {
          // New structure - extract list names from the map keys
          final memberships = data['list_memberships'] as Map<String, dynamic>;
          listNames = memberships.keys.toList();
        } else if (data['lists'] != null) {
          // Old structure - lists is an array
          listNames = List<String>.from(data['lists'] ?? []);
        }
        
        return {
          'id': doc.id,
          'contact_name': data['contact_name'] ?? '',
          'contact_phone_number': data['contact_phone_number'] ?? '',
          'normalized_phone': data['normalized_phone'] ?? '',
          'lists': listNames,
          'list_memberships': data['list_memberships'] ?? {},
          'created_at': data['created_at'],
          'updated_at': data['updated_at'],
        };
      }).toList();

      // Sort alphabetically by contact name
      fetchedContacts.sort((a, b) => 
        (a['contact_name'] as String).toLowerCase().compareTo(
          (b['contact_name'] as String).toLowerCase()
        )
      );

      if (mounted) {
        setState(() {
          contacts = fetchedContacts;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching contacts: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // Strips everything except digits from a phone number so we can
  // compare numbers that might have dashes, spaces, or country codes.
  String _normalizePhoneNumber(String phone) {
    // Remove all non-digit characters
    return phone.replaceAll(RegExp(r'[^\d]'), '');
  }

  // Writes the edited name/phone back to Firestore and
  // re-fetches the full list so the UI stays up to date.
  Future<void> _updateContact(String docId, String newName, String newPhone) async {
    try {
      final normalizedPhone = _normalizePhoneNumber(newPhone);
      await FirebaseFirestore.instance
          .collection('Contact Directories')
          .doc(docId)
          .update({
            'contact_name': newName,
            'contact_phone_number': newPhone,
            'normalized_phone': normalizedPhone,
            'updated_at': FieldValue.serverTimestamp(),
          });
      
      await _fetchContacts();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Contact updated successfully'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      print('Error updating contact: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update contact'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // Shows a confirmation dialog, then permanently removes the
  // contact document from Firestore if the user confirms.
  Future<bool> _deleteContact(String docId, String contactName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Contact',
          style: AppleTypography.withAppleFont(
            AppleTypography.headline5.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$contactName"? This action cannot be undone.',
          style: AppleTypography.withAppleFont(AppleTypography.body1),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppleTypography.withAppleFont(
                AppleTypography.body1.copyWith(color: Colors.grey.shade600),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Delete',
              style: AppleTypography.withAppleFont(
                AppleTypography.body1.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('Contact Directories')
            .doc(docId)
            .delete();
        
        await _fetchContacts();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Contact deleted successfully'),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return true;
      } catch (e) {
        print('Error deleting contact: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete contact'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return false;
      }
    }
    return false;
  }

  // Opens an edit dialog with name/phone fields plus a list of
  // every list this contact belongs to, for quick reference.
  void _showEditDialog(Map<String, dynamic> contact) {
    final nameController = TextEditingController(text: contact['contact_name']);
    final phoneController = TextEditingController(text: contact['contact_phone_number']);
    final List lists = contact['lists'] ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color.fromRGBO(64, 105, 225, 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.edit,
                color: Color.fromRGBO(64, 105, 225, 1),
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Edit Contact',
                style: AppleTypography.withAppleFont(
                  AppleTypography.headline5.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            // Prediction button
            IconButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CallPredictionView(
                      contactName: contact['contact_name'] ?? 'Unknown',
                      phoneNumber: contact['contact_phone_number'] ?? '',
                    ),
                  ),
                );
              },
              icon: Icon(
                Icons.analytics_outlined,
                color: Color.fromRGBO(64, 105, 225, 1),
              ),
              tooltip: 'View Call Predictions',
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Contact Name',
                  labelStyle: AppleTypography.withAppleFont(AppleTypography.body2),
                  prefixIcon: Icon(Icons.person_outline, color: Colors.grey.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color.fromRGBO(64, 105, 225, 1), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                style: AppleTypography.withAppleFont(AppleTypography.body1),
              ),
              SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: AppleTypography.withAppleFont(AppleTypography.body2),
                  prefixIcon: Icon(Icons.phone_outlined, color: Colors.grey.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color.fromRGBO(64, 105, 225, 1), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                keyboardType: TextInputType.phone,
                style: AppleTypography.withAppleFont(AppleTypography.body1),
              ),
              // Lists section
              if (lists.isNotEmpty) ...[
                SizedBox(height: 20),
                Text(
                  'Member of Lists',
                  style: AppleTypography.withAppleFont(
                    AppleTypography.subtitle1.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: lists.map<Widget>((list) {
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(64, 105, 225, 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Color.fromRGBO(64, 105, 225, 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.list,
                              size: 14,
                              color: Color.fromRGBO(64, 105, 225, 1),
                            ),
                            SizedBox(width: 6),
                            Text(
                              list.toString(),
                              style: AppleTypography.withAppleFont(
                                AppleTypography.body2.copyWith(
                                  color: Color.fromRGBO(64, 105, 225, 1),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppleTypography.withAppleFont(
                AppleTypography.body1.copyWith(color: Colors.grey.shade600),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateContact(
                contact['id'],
                nameController.text.trim(),
                phoneController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color.fromRGBO(64, 105, 225, 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Save',
              style: AppleTypography.withAppleFont(
                AppleTypography.body1.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get filteredContacts {
    if (searchQuery.isEmpty) return contacts;
    return contacts.where((contact) {
      final name = (contact['contact_name'] as String).toLowerCase();
      final phone = (contact['contact_phone_number'] as String).toLowerCase();
      final query = searchQuery.toLowerCase();
      return name.contains(query) || phone.contains(query);
    }).toList();
  }

  // ============================================================================
  // Upload methods
  // ============================================================================

  /// Show the add contacts bottom sheet menu
  void _showAddContactsMenu() {
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: EdgeInsets.fromLTRB(20, 12, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Add Contacts to Directory',
                style: AppleTypography.withAppleFont(
                  AppleTypography.headline5.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Choose how you want to import contacts',
                style: AppleTypography.withAppleFont(
                  AppleTypography.body2.copyWith(color: Colors.grey.shade500),
                ),
              ),
              SizedBox(height: 20),
              // Option 1: Upload from Phone Contacts
              _buildMenuOption(
                icon: Icons.contacts,
                iconColor: Colors.blue.shade700,
                bgColor: Colors.blue.shade100,
                title: 'Upload from Phone Contacts',
                subtitle: 'Select contacts from your device',
                onTap: () {
                  Navigator.pop(context);
                  _uploadFromPhoneContacts();
                },
              ),
              SizedBox(height: 10),
              // Option 2: Upload from Excel Spreadsheet
              _buildMenuOption(
                icon: Icons.table_chart,
                iconColor: Colors.green.shade700,
                bgColor: Colors.green.shade100,
                title: 'Upload from Spreadsheet',
                subtitle: 'Import contacts from Excel or CSV file',
                onTap: () {
                  Navigator.pop(context);
                  _uploadFromExcel();
                },
              ),
              SizedBox(height: 16),
              // Spreadsheet format info
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade600, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Spreadsheet columns: "Name" and "Phone" (supports .xlsx, .xls, .csv)',
                        style: AppleTypography.withAppleFont(
                          AppleTypography.caption.copyWith(color: Colors.blue.shade700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppleTypography.withAppleFont(
                        AppleTypography.subtitle1.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppleTypography.withAppleFont(
                        AppleTypography.body2.copyWith(color: Colors.grey.shade500),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  // Bulk-upload from the phone's native contacts.
  // Loads contacts in batches of 50 to keep memory usage reasonable,
  // checks for duplicates by normalized phone number, and lets the
  // user choose to skip or overwrite existing entries.
  /// Upload contacts from the device's phone contacts
  Future<void> _uploadFromPhoneContacts() async {
    try {
      // Request permission
      bool permission = await fc.FlutterContacts.requestPermission();
      if (!permission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Contact permission denied'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }

      // Show loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color.fromRGBO(64, 105, 225, 1)),
                  SizedBox(width: 20),
                  Text('Loading contacts...', style: AppleTypography.withAppleFont(AppleTypography.body1)),
                ],
              ),
            ),
          ),
        );
      }

      // Fetch all phone contacts
      List<SimpleContact> simpleContacts = [];
      try {
        List<fc.Contact> lightContacts = await fc.FlutterContacts.getContacts(
          withProperties: false,
          withPhoto: false,
        );

        const int batchSize = 50;
        for (int i = 0; i < lightContacts.length; i += batchSize) {
          int end = (i + batchSize < lightContacts.length) ? i + batchSize : lightContacts.length;
          List<fc.Contact> batch = lightContacts.sublist(i, end);

          for (fc.Contact lightContact in batch) {
            try {
              fc.Contact? fullContact = await fc.FlutterContacts.getContact(lightContact.id);
              if (fullContact != null && fullContact.phones.isNotEmpty) {
                simpleContacts.add(SimpleContact(
                  id: fullContact.id,
                  displayName: fullContact.displayName,
                  phoneNumber: fullContact.phones.first.number,
                ));
              }
            } catch (e) {
              continue;
            }
          }
          await Future.delayed(Duration(milliseconds: 10));
        }
      } catch (e) {
        print('Error loading contacts: $e');
      }

      // Dismiss loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (simpleContacts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No contacts with phone numbers found'),
              backgroundColor: Colors.orange.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }

      // Show multi-select dialog
      if (!mounted) return;
      List<SimpleContact>? selectedContacts = await showDialog<List<SimpleContact>>(
        context: context,
        builder: (context) => MultiContactSelectDialog(contacts: simpleContacts),
      );

      if (selectedContacts == null || selectedContacts.isEmpty) return;

      // Convert to ExcelContact for duplicate checking
      final excelContacts = selectedContacts.map((c) => ExcelContact(
        name: c.displayName,
        phoneNumber: c.phoneNumber,
      )).toList();

      // Check for duplicates
      final duplicateResult = await ExcelImportService.checkForDuplicates(excelContacts);

      List<ExcelContact> contactsToUpload = List.from(duplicateResult.newContacts);

      if (duplicateResult.duplicateContacts.isNotEmpty && mounted) {
        final action = await ExcelImportService.showDuplicateDialog(
          context,
          duplicateResult.duplicateContacts,
        );

        if (action == null) return; // Cancelled
        if (action == 'overwrite') {
          contactsToUpload.addAll(duplicateResult.duplicateContacts);
        }
        // 'skip' means we just upload newContacts
      }

      if (contactsToUpload.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No new contacts to import'),
              backgroundColor: Colors.orange.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }

      // Show uploading progress
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color.fromRGBO(64, 105, 225, 1)),
                  SizedBox(width: 20),
                  Text('Uploading ${contactsToUpload.length} contacts...', style: AppleTypography.withAppleFont(AppleTypography.body1)),
                ],
              ),
            ),
          ),
        );
      }

      final uploadedCount = await ExcelImportService.uploadContactsToDirectory(
        contactsToUpload,
        overwriteExisting: duplicateResult.duplicateContacts.isNotEmpty,
      );

      // Dismiss progress dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Refresh and show success
      await _fetchContacts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported $uploadedCount contact${uploadedCount == 1 ? '' : 's'}'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      print('Error uploading phone contacts: $e');
      if (mounted) {
        // Dismiss any open dialogs
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import contacts: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // Picks an Excel or CSV file via the file picker, parses it through
  // ExcelImportService, deduplicates against existing contacts, and
  // writes the new entries to Firestore's Contact Directories.
  /// Upload contacts from an Excel/CSV spreadsheet
  Future<void> _uploadFromExcel() async {
    try {
      // Pick and parse Excel file
      final contacts = await ExcelImportService.pickAndParseExcel(context);
      if (contacts == null || contacts.isEmpty) return;

      // Show parsed contact count
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color.fromRGBO(64, 105, 225, 1)),
                  SizedBox(width: 20),
                  Text('Checking ${contacts.length} contacts...', style: AppleTypography.withAppleFont(AppleTypography.body1)),
                ],
              ),
            ),
          ),
        );
      }

      // Check for duplicates
      final duplicateResult = await ExcelImportService.checkForDuplicates(contacts);

      // Dismiss checking dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      List<ExcelContact> contactsToUpload = List.from(duplicateResult.newContacts);
      bool overwrite = false;

      // If there are duplicates, ask the user
      if (duplicateResult.duplicateContacts.isNotEmpty && mounted) {
        final action = await ExcelImportService.showDuplicateDialog(
          context,
          duplicateResult.duplicateContacts,
        );

        if (action == null) return; // Cancelled
        if (action == 'overwrite') {
          contactsToUpload.addAll(duplicateResult.duplicateContacts);
          overwrite = true;
        }
      }

      if (contactsToUpload.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No new contacts to import'),
              backgroundColor: Colors.orange.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }

      // Show uploading progress
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color.fromRGBO(64, 105, 225, 1)),
                  SizedBox(width: 20),
                  Text('Uploading ${contactsToUpload.length} contacts...', style: AppleTypography.withAppleFont(AppleTypography.body1)),
                ],
              ),
            ),
          ),
        );
      }

      final uploadedCount = await ExcelImportService.uploadContactsToDirectory(
        contactsToUpload,
        overwriteExisting: overwrite,
      );

      // Dismiss progress dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Refresh and show success
      await _fetchContacts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported $uploadedCount contact${uploadedCount == 1 ? '' : 's'} from spreadsheet'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      print('Error uploading from Excel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import spreadsheet: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(248, 248, 250, 1),
      // Floating Action Button with Apple Liquid Glass style
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromRGBO(64, 105, 225, 1),
              Color.fromRGBO(100, 140, 255, 1),
            ],
          ),
        ),
        child: CNButton.icon(
          icon: const CNSymbol('plus', size: 22),
          style: CNButtonStyle.prominentGlass,
          onPressed: _showAddContactsMenu,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact Directory',
                    style: AppleTypography.withAppleFont(
                      AppleTypography.headline3.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Color.fromRGBO(64, 105, 225, 1),
                      ),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${contacts.length} contacts',
                    style: AppleTypography.withAppleFont(
                      AppleTypography.body2.copyWith(color: Colors.grey.shade600),
                    ),
                  ),
                  SizedBox(height: 16),
                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() => searchQuery = value);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search contacts...',
                        hintStyle: AppleTypography.withAppleFont(
                          AppleTypography.body1.copyWith(color: Colors.grey.shade500),
                        ),
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey.shade500),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      style: AppleTypography.withAppleFont(AppleTypography.body1),
                    ),
                  ),
                ],
              ),
            ),
            // Contact List
            Expanded(
              child: isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Color.fromRGBO(64, 105, 225, 1),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading contacts...',
                            style: AppleTypography.withAppleFont(
                              AppleTypography.body1.copyWith(color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                    )
                  : filteredContacts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.contacts_outlined,
                                size: 80,
                                color: Colors.grey.shade300,
                              ),
                              SizedBox(height: 16),
                              Text(
                                searchQuery.isNotEmpty
                                    ? 'No contacts found'
                                    : 'No contacts yet',
                                style: AppleTypography.withAppleFont(
                                  AppleTypography.headline5.copyWith(
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                searchQuery.isNotEmpty
                                    ? 'Try a different search term'
                                    : 'Contacts will appear here',
                                style: AppleTypography.withAppleFont(
                                  AppleTypography.body1.copyWith(color: Colors.grey.shade400),
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchContacts,
                          color: Color.fromRGBO(64, 105, 225, 1),
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: filteredContacts.length,
                            itemBuilder: (context, index) {
                              final contact = filteredContacts[index];
                              final String name = contact['contact_name'] ?? 'Unknown';
                              final String phone = contact['contact_phone_number'] ?? '';
                              final List lists = contact['lists'] ?? [];
                              final String initials = name.isNotEmpty
                                  ? name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
                                  : '?';

                              return Dismissible(
                                key: Key(contact['id']),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (direction) async {
                                  return await _deleteContact(contact['id'], name);
                                },
                                background: Container(
                                  margin: EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.centerRight,
                                  padding: EdgeInsets.only(right: 20),
                                  child: Icon(
                                    Icons.delete_outline,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                child: Container(
                                  margin: EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => _showEditDialog(contact),
                                      child: Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            // Avatar
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Color.fromRGBO(64, 105, 225, 1),
                                                  Color.fromRGBO(100, 140, 255, 1),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: Center(
                                              child: Text(
                                                initials,
                                                style: AppleTypography.withAppleFont(
                                                  AppleTypography.subtitle1.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 14),
                                          // Contact info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: AppleTypography.withAppleFont(
                                                    AppleTypography.subtitle1.copyWith(
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.grey.shade800,
                                                    ),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.phone_outlined,
                                                      size: 14,
                                                      color: Colors.grey.shade500,
                                                    ),
                                                    SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        phone.isNotEmpty ? phone : 'No phone number',
                                                        style: AppleTypography.withAppleFont(
                                                          AppleTypography.body2.copyWith(
                                                            color: Colors.grey.shade600,
                                                          ),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (lists.isNotEmpty) ...[
                                                  SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Wrap(
                                                          spacing: 6,
                                                          runSpacing: 4,
                                                          children: [
                                                            ...lists.take(2).map<Widget>((list) {
                                                              return Container(
                                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                                decoration: BoxDecoration(
                                                                  color: Color.fromRGBO(64, 105, 225, 0.1),
                                                                  borderRadius: BorderRadius.circular(6),
                                                                ),
                                                                child: Text(
                                                                  list.toString(),
                                                                  style: AppleTypography.withAppleFont(
                                                                    AppleTypography.caption.copyWith(
                                                                      color: Color.fromRGBO(64, 105, 225, 1),
                                                                      fontWeight: FontWeight.w500,
                                                                    ),
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              );
                                                            }),
                                                            if (lists.length > 2)
                                                              Container(
                                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                                decoration: BoxDecoration(
                                                                  color: Colors.grey.shade200,
                                                                  borderRadius: BorderRadius.circular(6),
                                                                ),
                                                                child: Text(
                                                                  '+${lists.length - 2} more',
                                                                  style: AppleTypography.withAppleFont(
                                                                    AppleTypography.caption.copyWith(
                                                                      color: Colors.grey.shade600,
                                                                      fontWeight: FontWeight.w500,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          // Edit indicator
                                          Icon(
                                            Icons.chevron_right,
                                            color: Colors.grey.shade400,
                                            size: 24,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
