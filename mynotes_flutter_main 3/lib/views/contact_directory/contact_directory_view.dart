import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/utilities/apple_typography.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';

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

  String _normalizePhoneNumber(String phone) {
    // Remove all non-digit characters
    return phone.replaceAll(RegExp(r'[^\d]'), '');
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(248, 248, 250, 1),
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
