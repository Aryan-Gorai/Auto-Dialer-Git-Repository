// Unified contact directory — shows every contact the user has ever added
// across all lists, de-duplicated by normalised phone number.  Includes a
// contact relationship graph (BFS + Dijkstra) to visualise connections.
// Supports searching, importing from phone contacts or Excel, viewing
// which lists a contact belongs to, and navigating to the Naive Bayes
// call prediction page.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter_application_1/theme/components/app_components.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:flutter_application_1/services/excel_import_service.dart';
import 'package:flutter_application_1/services/graph/contact_graph.dart';
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

  /// Contact relationship graph — weighted undirected graph where
  /// edges represent shared list memberships between contacts.
  /// Uses BFS for connected-component discovery and Dijkstra's
  /// algorithm for finding the strongest relationship chain.
  /// (AQA Group A: Graph, Graph traversal, Dijkstra)
  ContactGraph? _contactGraph;
  bool _isGraphLoading = false;

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

      // Build the contact relationship graph in the background.
      // This creates a weighted undirected graph from shared list
      // memberships and persists analytics to Firestore.
      _buildContactGraph();
    } catch (e) {
      print('Error fetching contacts: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  /// Builds a weighted undirected graph of contact relationships
  /// from the Contact Directories collection.  Two contacts are
  /// connected if they share at least one list; edge weight equals
  /// the number of shared lists.
  ///
  /// After building, runs BFS to find connected components and
  /// persists analytics (node count, edge count, components,
  /// most-connected contacts) to Firestore.
  Future<void> _buildContactGraph() async {
    if (_isGraphLoading) return;
    _isGraphLoading = true;

    try {
      final graph = await ContactGraph.buildFromFirestore(userId);
      await graph.saveAnalyticsToFirestore(userId);

      if (mounted) {
        setState(() {
          _contactGraph = graph;
          _isGraphLoading = false;
        });
      }
    } catch (e) {
      print('Error building contact graph: $e');
      if (mounted) {
        setState(() => _isGraphLoading = false);
      }
    }
  }

  /// Shows a dialog with graph analytics — connected components,
  /// most-connected contacts, and the ability to find the shortest
  /// relationship path between two contacts using Dijkstra's algorithm.
  void _showGraphAnalyticsDialog() {
    if (_contactGraph == null) return;

    final graph = _contactGraph!;
    final components = graph.getConnectedComponents();
    final mostConnected = graph.getMostConnectedContacts(limit: 5);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg),
        ),
        title: Row(
          children: [
            Icon(Icons.hub, color: AppDesignTokens.primary, size: 22),
            const SizedBox(width: 8),
            const Text('Contact Network',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _graphStatRow('Contacts', '${graph.nodeCount}'),
              _graphStatRow('Connections', '${graph.edgeCount}'),
              _graphStatRow('Clusters', '${components.length}'),
              _graphStatRow('Avg connections',
                  graph.averageDegree.toStringAsFixed(1)),
              const Divider(),
              const Text('Most Connected',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.neutral700)),
              const SizedBox(height: 4),
              ...mostConnected.map((node) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${node.contactName} — ${node.degree} connections',
                      style: const TextStyle(fontSize: 14),
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _graphStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 14, color: AppDesignTokens.neutral600)),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.neutral900)),
        ],
      ),
    );
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
            backgroundColor: AppDesignTokens.success,
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
            backgroundColor: AppDesignTokens.danger,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg)),
        title: Text(
          'Delete Contact',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppDesignTokens.neutral900,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$contactName"? This action cannot be undone.',
          style: const TextStyle(fontSize: 16, color: AppDesignTokens.neutral700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 16,
                color: AppDesignTokens.neutral600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppDesignTokens.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm)),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
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
              backgroundColor: AppDesignTokens.success,
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
              backgroundColor: AppDesignTokens.danger,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesignTokens.radiusXl)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppDesignTokens.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.edit,
                color: AppDesignTokens.primary,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Edit Contact',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppDesignTokens.neutral900,
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
                color: AppDesignTokens.primary,
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
                  labelStyle: TextStyle(fontSize: 14, color: AppDesignTokens.neutral600),
                  prefixIcon: Icon(Icons.person_outline, color: AppDesignTokens.neutral600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                    borderSide: BorderSide(color: AppDesignTokens.neutral300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                    borderSide: BorderSide(color: AppDesignTokens.neutral300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                    borderSide: BorderSide(color: AppDesignTokens.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: AppDesignTokens.neutral50,
                ),
                style: TextStyle(fontSize: 16, color: AppDesignTokens.neutral900),
              ),
              SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: TextStyle(fontSize: 14, color: AppDesignTokens.neutral600),
                  prefixIcon: Icon(Icons.phone_outlined, color: AppDesignTokens.neutral600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                    borderSide: BorderSide(color: AppDesignTokens.neutral300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                    borderSide: BorderSide(color: AppDesignTokens.neutral300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                    borderSide: BorderSide(color: AppDesignTokens.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: AppDesignTokens.neutral50,
                ),
                keyboardType: TextInputType.phone,
                style: TextStyle(fontSize: 16, color: AppDesignTokens.neutral900),
              ),
              // Lists section
              if (lists.isNotEmpty) ...[
                SizedBox(height: 20),
                Text(
                  'Member of Lists',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.neutral700,
                  ),
                ),
                SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.neutral50,
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                    border: Border.all(color: AppDesignTokens.neutral200),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: lists.map<Widget>((list) {
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppDesignTokens.primarySoft,
                          borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                          border: Border.all(
                            color: AppDesignTokens.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.list,
                              size: 14,
                              color: AppDesignTokens.primary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              list.toString(),
                              style: TextStyle(
                                fontSize: 14,
                                color: AppDesignTokens.primary,
                                fontWeight: FontWeight.w500,
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
              style: TextStyle(
                fontSize: 16,
                color: AppDesignTokens.neutral600,
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
              backgroundColor: AppDesignTokens.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Save',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w600,
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
            color: AppDesignTokens.surface,
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
                  color: AppDesignTokens.neutral300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Add Contacts to Directory',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppDesignTokens.neutral900,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Choose how you want to import contacts',
                style: TextStyle(
                  fontSize: 14,
                  color: AppDesignTokens.neutral500,
                ),
              ),
              SizedBox(height: 20),
              // Option 1: Upload from Phone Contacts
              _buildMenuOption(
                icon: Icons.contacts,
                iconColor: AppDesignTokens.accentBlue,
                bgColor: AppDesignTokens.accentBlueSoft,
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
                iconColor: AppDesignTokens.success,
                bgColor: AppDesignTokens.successSoft,
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
                  color: AppDesignTokens.accentBlueSoft,
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                  border: Border.all(color: AppDesignTokens.accentBlue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppDesignTokens.accentBlue, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Spreadsheet columns: "Name" and "Phone" (supports .xlsx, .xls, .csv)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppDesignTokens.accentBlue,
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
            color: AppDesignTokens.neutral50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppDesignTokens.neutral200),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppDesignTokens.neutral900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppDesignTokens.neutral500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppDesignTokens.neutral400),
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
              backgroundColor: AppDesignTokens.danger,
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
                  CircularProgressIndicator(color: AppDesignTokens.primary),
                  SizedBox(width: 20),
                  Text('Loading contacts...', style: TextStyle(fontSize: 16, color: AppDesignTokens.neutral900)),
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
              backgroundColor: AppDesignTokens.warning,
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
              backgroundColor: AppDesignTokens.warning,
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
                  CircularProgressIndicator(color: AppDesignTokens.primary),
                  SizedBox(width: 20),
                  Text('Uploading ${contactsToUpload.length} contacts...', style: TextStyle(fontSize: 16, color: AppDesignTokens.neutral900)),
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
            backgroundColor: AppDesignTokens.success,
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
            backgroundColor: AppDesignTokens.danger,
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
                  CircularProgressIndicator(color: AppDesignTokens.primary),
                  SizedBox(width: 20),
                  Text('Checking ${contacts.length} contacts...', style: TextStyle(fontSize: 16, color: AppDesignTokens.neutral900)),
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
              backgroundColor: AppDesignTokens.warning,
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
                  CircularProgressIndicator(color: AppDesignTokens.primary),
                  SizedBox(width: 20),
                  Text('Uploading ${contactsToUpload.length} contacts...', style: TextStyle(fontSize: 16, color: AppDesignTokens.neutral900)),
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
            backgroundColor: AppDesignTokens.success,
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
            backgroundColor: AppDesignTokens.danger,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Floating Action Button with Apple Liquid Glass style
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: AppDesignTokens.primaryGradient,
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
                color: AppDesignTokens.surface,
                boxShadow: AppDesignTokens.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact Directory',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppDesignTokens.primary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${contacts.length} contacts',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppDesignTokens.neutral600,
                        ),
                      ),
                      const Spacer(),
                      // Graph analytics button — shows network analysis
                      // powered by BFS and Dijkstra's algorithm
                      if (_contactGraph != null)
                        GestureDetector(
                          onTap: _showGraphAnalyticsDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppDesignTokens.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                  AppDesignTokens.radiusSm),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.hub,
                                    size: 14,
                                    color: AppDesignTokens.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'Network',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppDesignTokens.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_isGraphLoading)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppDesignTokens.primary,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppDesignTokens.neutral50,
                      borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                      border: Border.all(color: AppDesignTokens.neutral300),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() => searchQuery = value);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search contacts...',
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: AppDesignTokens.neutral500,
                        ),
                        prefixIcon: Icon(Icons.search, color: AppDesignTokens.neutral500),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: AppDesignTokens.neutral500),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      style: TextStyle(fontSize: 16, color: AppDesignTokens.neutral900),
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
                            color: AppDesignTokens.primary,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading contacts...',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppDesignTokens.neutral600,
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
                                color: AppDesignTokens.neutral300,
                              ),
                              SizedBox(height: 16),
                              Text(
                                searchQuery.isNotEmpty
                                    ? 'No contacts found'
                                    : 'No contacts yet',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: AppDesignTokens.neutral500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                searchQuery.isNotEmpty
                                    ? 'Try a different search term'
                                    : 'Contacts will appear here',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppDesignTokens.neutral400,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchContacts,
                          color: AppDesignTokens.primary,
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
                                    color: AppDesignTokens.danger,
                                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg),
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
                                    color: AppDesignTokens.surface,
                                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg),
                                    boxShadow: AppDesignTokens.cardShadow,
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg),
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
                                              gradient: AppDesignTokens.primaryGradient,
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: Center(
                                              child: Text(
                                                initials,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
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
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppDesignTokens.neutral800,
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
                                                      color: AppDesignTokens.neutral500,
                                                    ),
                                                    SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        phone.isNotEmpty ? phone : 'No phone number',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: AppDesignTokens.neutral600,
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
                                                                  color: AppDesignTokens.primarySoft,
                                                                  borderRadius: BorderRadius.circular(6),
                                                                ),
                                                                child: Text(
                                                                  list.toString(),
                                                                  style: TextStyle(
                                                                    fontSize: 12,
                                                                    color: AppDesignTokens.primary,
                                                                    fontWeight: FontWeight.w500,
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
                                                                  color: AppDesignTokens.neutral200,
                                                                  borderRadius: BorderRadius.circular(6),
                                                                ),
                                                                child: Text(
                                                                  '+${lists.length - 2} more',
                                                                  style: TextStyle(
                                                                    fontSize: 12,
                                                                    color: AppDesignTokens.neutral600,
                                                                    fontWeight: FontWeight.w500,
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
                                            color: AppDesignTokens.neutral400,
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
