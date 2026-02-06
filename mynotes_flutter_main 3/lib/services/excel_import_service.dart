import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:flutter_application_1/utilities/apple_typography.dart';
import 'package:flutter_application_1/views/list/firebase_services.dart';

/// Represents a contact parsed from an Excel spreadsheet
class ExcelContact {
  final String name;
  final String phoneNumber;

  ExcelContact({required this.name, required this.phoneNumber});

  @override
  String toString() => '$name ($phoneNumber)';
}

/// Result of checking for duplicates
class DuplicateCheckResult {
  final List<ExcelContact> newContacts;
  final List<ExcelContact> duplicateContacts;
  final Map<String, Map<String, dynamic>> existingDataMap; // normalized_phone -> existing doc data

  DuplicateCheckResult({
    required this.newContacts,
    required this.duplicateContacts,
    required this.existingDataMap,
  });
}

class ExcelImportService {
  static String get _userId => AuthService.firebase().currentUser!.id;

  /// Pick an Excel file from the device and parse contacts from it
  /// Expected columns: "Name" (or "Contact Name") and "Phone" (or "Phone Number")
  static Future<List<ExcelContact>?> pickAndParseExcel(BuildContext context) async {
    try {
      // Open file picker for Excel files
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return null; // User cancelled
      }

      final file = result.files.first;
      if (file.path == null) {
        if (context.mounted) {
          _showError(context, 'Could not access the selected file.');
        }
        return null;
      }

      final bytes = File(file.path!).readAsBytesSync();
      
      // Check if it's a CSV file
      if (file.extension?.toLowerCase() == 'csv') {
        return _parseCsv(context, bytes);
      }

      // Parse Excel file
      final excel = Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) {
        if (context.mounted) {
          _showError(context, 'The spreadsheet is empty or could not be read.');
        }
        return null;
      }

      // Get the first sheet
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName]!;

      if (sheet.rows.isEmpty) {
        if (context.mounted) {
          _showError(context, 'The spreadsheet has no data rows.');
        }
        return null;
      }

      // Find header row and identify columns
      int nameColIndex = -1;
      int phoneColIndex = -1;

      final headerRow = sheet.rows.first;
      for (int i = 0; i < headerRow.length; i++) {
        final cellValue = headerRow[i]?.value?.toString().toLowerCase().trim() ?? '';
        if (cellValue == 'name' || cellValue == 'contact name' || cellValue == 'contact_name' || cellValue == 'full name') {
          nameColIndex = i;
        } else if (cellValue == 'phone' || cellValue == 'phone number' || cellValue == 'contact_phone_number' || cellValue == 'phone_number' || cellValue == 'number') {
          phoneColIndex = i;
        }
      }

      if (nameColIndex == -1 || phoneColIndex == -1) {
        if (context.mounted) {
          _showColumnError(context);
        }
        return null;
      }

      // Parse data rows (skip header)
      List<ExcelContact> contacts = [];
      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final name = _getCellValue(row, nameColIndex);
        final phone = _getCellValue(row, phoneColIndex);

        if (name.isNotEmpty && phone.isNotEmpty) {
          contacts.add(ExcelContact(
            name: name.trim(),
            phoneNumber: _formatPhoneNumber(phone.trim()),
          ));
        }
      }

      if (contacts.isEmpty) {
        if (context.mounted) {
          _showError(context, 'No valid contacts found in the spreadsheet. Ensure there are rows with both Name and Phone values.');
        }
        return null;
      }

      return contacts;
    } catch (e) {
      print('Error parsing Excel: $e');
      if (context.mounted) {
        _showError(context, 'Failed to parse the spreadsheet: ${e.toString()}');
      }
      return null;
    }
  }

  /// Parse CSV file
  static List<ExcelContact>? _parseCsv(BuildContext context, List<int> bytes) {
    try {
      final content = String.fromCharCodes(bytes);
      final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();

      if (lines.isEmpty) {
        if (context.mounted) {
          _showError(context, 'The CSV file is empty.');
        }
        return null;
      }

      // Parse header
      final headers = lines.first.split(',').map((h) => h.trim().toLowerCase()).toList();
      int nameColIndex = -1;
      int phoneColIndex = -1;

      for (int i = 0; i < headers.length; i++) {
        final h = headers[i].replaceAll('"', '').trim();
        if (h == 'name' || h == 'contact name' || h == 'contact_name' || h == 'full name') {
          nameColIndex = i;
        } else if (h == 'phone' || h == 'phone number' || h == 'contact_phone_number' || h == 'phone_number' || h == 'number') {
          phoneColIndex = i;
        }
      }

      if (nameColIndex == -1 || phoneColIndex == -1) {
        if (context.mounted) {
          _showColumnError(context);
        }
        return null;
      }

      List<ExcelContact> contacts = [];
      for (int i = 1; i < lines.length; i++) {
        final cols = lines[i].split(',').map((c) => c.trim().replaceAll('"', '')).toList();
        if (cols.length > nameColIndex && cols.length > phoneColIndex) {
          final name = cols[nameColIndex].trim();
          final phone = cols[phoneColIndex].trim();
          if (name.isNotEmpty && phone.isNotEmpty) {
            contacts.add(ExcelContact(name: name, phoneNumber: _formatPhoneNumber(phone)));
          }
        }
      }

      if (contacts.isEmpty) {
        if (context.mounted) {
          _showError(context, 'No valid contacts found in the CSV file.');
        }
        return null;
      }

      return contacts;
    } catch (e) {
      print('Error parsing CSV: $e');
      if (context.mounted) {
        _showError(context, 'Failed to parse the CSV file.');
      }
      return null;
    }
  }

  /// Check for duplicate contacts in Firebase
  static Future<DuplicateCheckResult> checkForDuplicates(List<ExcelContact> contacts) async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore
        .collection('Contact Directories')
        .where('user_id', isEqualTo: _userId)
        .get();

    // Build a map of existing contacts by normalized phone
    Map<String, Map<String, dynamic>> existingByPhone = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final normalizedPhone = data['normalized_phone'] as String? ?? '';
      if (normalizedPhone.isNotEmpty) {
        existingByPhone[normalizedPhone] = {
          ...data,
          'doc_id': doc.id,
        };
      }
    }

    List<ExcelContact> newContacts = [];
    List<ExcelContact> duplicateContacts = [];

    for (var contact in contacts) {
      final normalized = normalizePhone(contact.phoneNumber);
      if (existingByPhone.containsKey(normalized)) {
        duplicateContacts.add(contact);
      } else {
        newContacts.add(contact);
      }
    }

    return DuplicateCheckResult(
      newContacts: newContacts,
      duplicateContacts: duplicateContacts,
      existingDataMap: existingByPhone,
    );
  }

  /// Upload contacts to Firebase Contact Directories (not linked to any list)
  static Future<int> uploadContactsToDirectory(
    List<ExcelContact> contacts, {
    bool overwriteExisting = false,
  }) async {
    final firestore = FirebaseFirestore.instance;
    int uploadedCount = 0;

    for (var contact in contacts) {
      try {
        final normalizedPhoneNum = normalizePhone(contact.phoneNumber);
        final docId = '${_userId}_$normalizedPhoneNum';
        final docRef = firestore.collection('Contact Directories').doc(docId);
        final now = FieldValue.serverTimestamp();

        final existing = await docRef.get();

        if (existing.exists && !overwriteExisting) {
          // Skip existing (shouldn't reach here normally since we filter earlier)
          continue;
        }

        if (existing.exists && overwriteExisting) {
          // Overwrite - keep list_memberships, update name and phone
          await docRef.update({
            'contact_name': contact.name,
            'contact_phone_number': contact.phoneNumber,
            'normalized_phone': normalizedPhoneNum,
            'updated_at': now,
          });
        } else {
          // Create new
          await docRef.set({
            'contact_name': contact.name,
            'contact_phone_number': contact.phoneNumber,
            'normalized_phone': normalizedPhoneNum,
            'user_id': _userId,
            'list_memberships': {},
            'created_at': now,
            'updated_at': now,
          });
        }
        uploadedCount++;
      } catch (e) {
        print('Error uploading contact ${contact.name}: $e');
      }
    }

    return uploadedCount;
  }

  /// Upload contacts from Excel to a specific list
  static Future<int> uploadContactsToList(
    List<ExcelContact> contacts,
    String listName, {
    bool overwriteExisting = false,
  }) async {
    int uploadedCount = 0;

    for (var contact in contacts) {
      try {
        await addContactToList(
          contactName: contact.name,
          contactPhoneNumber: contact.phoneNumber,
          listName: listName,
        );
        uploadedCount++;
      } catch (e) {
        print('Error uploading contact ${contact.name} to list: $e');
      }
    }

    return uploadedCount;
  }

  /// Show the duplicate handling dialog
  /// Returns: 'skip' to skip duplicates, 'overwrite' to overwrite, null if cancelled
  static Future<String?> showDuplicateDialog(
    BuildContext context,
    List<ExcelContact> duplicates,
  ) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade700,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Duplicate Contacts Found',
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
                Text(
                  '${duplicates.length} contact${duplicates.length == 1 ? '' : 's'} already exist in your directory:',
                  style: AppleTypography.withAppleFont(
                    AppleTypography.body1.copyWith(color: Colors.grey.shade700),
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  constraints: BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.all(8),
                    itemCount: duplicates.length > 10 ? 10 : duplicates.length,
                    separatorBuilder: (_, __) => Divider(height: 1),
                    itemBuilder: (context, index) {
                      final contact = duplicates[index];
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        child: Row(
                          children: [
                            Icon(Icons.person, size: 16, color: Colors.grey.shade500),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${contact.name} - ${contact.phoneNumber}',
                                style: AppleTypography.withAppleFont(
                                  AppleTypography.body2.copyWith(color: Colors.grey.shade700),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (duplicates.length > 10) ...[
                  SizedBox(height: 8),
                  Text(
                    '...and ${duplicates.length - 10} more',
                    style: AppleTypography.withAppleFont(
                      AppleTypography.caption.copyWith(color: Colors.grey.shade500),
                    ),
                  ),
                ],
                SizedBox(height: 16),
                Text(
                  'What would you like to do?',
                  style: AppleTypography.withAppleFont(
                    AppleTypography.body1.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(
                'Cancel',
                style: AppleTypography.withAppleFont(
                  AppleTypography.body1.copyWith(color: Colors.grey.shade600),
                ),
              ),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, 'skip'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Color.fromRGBO(64, 105, 225, 1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Skip Duplicates',
                style: AppleTypography.withAppleFont(
                  AppleTypography.body1.copyWith(
                    color: Color.fromRGBO(64, 105, 225, 1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'overwrite'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Overwrite',
                style: AppleTypography.withAppleFont(
                  AppleTypography.body1.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================================
  // Helper methods
  // ============================================================================

  static String _getCellValue(List<Data?> row, int index) {
    if (index >= row.length || row[index] == null) return '';
    final value = row[index]!.value;
    if (value == null) return '';
    return value.toString().trim();
  }

  static String _formatPhoneNumber(String phone) {
    // Clean up phone number: keep digits, +, and spaces
    String cleaned = phone.replaceAll(RegExp(r'[^\d+\s-]'), '').trim();
    // If it's purely digits without +, and looks like it might need a prefix
    // just return as-is to preserve whatever format the user provided
    return cleaned.isEmpty ? phone : cleaned;
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 4),
      ),
    );
  }

  static void _showColumnError(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Invalid Spreadsheet Format',
                style: AppleTypography.withAppleFont(
                  AppleTypography.headline5.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Could not find the required columns. Your spreadsheet must have these column headers in the first row:',
              style: AppleTypography.withAppleFont(AppleTypography.body1),
            ),
            SizedBox(height: 16),
            _buildColumnRequirement('Column 1:', 'Name', 'Also accepts: "Contact Name", "Full Name"'),
            SizedBox(height: 8),
            _buildColumnRequirement('Column 2:', 'Phone', 'Also accepts: "Phone Number", "Number"'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade600, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Supported formats: .xlsx, .xls, .csv',
                      style: AppleTypography.withAppleFont(
                        AppleTypography.body2.copyWith(color: Colors.blue.shade700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color.fromRGBO(64, 105, 225, 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'OK',
              style: AppleTypography.withAppleFont(
                AppleTypography.body1.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildColumnRequirement(String label, String columnName, String alternatives) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: AppleTypography.withAppleFont(
                  AppleTypography.body2.copyWith(color: Colors.grey.shade500),
                ),
              ),
              SizedBox(width: 6),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(64, 105, 225, 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  columnName,
                  style: AppleTypography.withAppleFont(
                    AppleTypography.body1.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(64, 105, 225, 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            alternatives,
            style: AppleTypography.withAppleFont(
              AppleTypography.caption.copyWith(color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }
}
