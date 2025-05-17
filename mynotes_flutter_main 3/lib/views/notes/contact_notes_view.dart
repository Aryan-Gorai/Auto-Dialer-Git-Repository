import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactNotesView extends StatefulWidget {
  final String contactName;
  final String contactPhoneNumber;
  final String listName;

  const ContactNotesView({
    Key? key,
    required this.contactName,
    required this.contactPhoneNumber,
    required this.listName,
  }) : super(key: key);

  @override
  State<ContactNotesView> createState() => _ContactNotesViewState();
}

class _ContactNotesViewState extends State<ContactNotesView> {
  bool isLoading = true;
  List<Map<String, dynamic>> callNotes = [];
  final TextEditingController _noteController = TextEditingController();
  
  String get userId => AuthService.firebase().currentUser!.id;

  @override
  void initState() {
    super.initState();
    fetchCallNotes();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> fetchCallNotes() async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot snapshot = await firestore
          .collection('contact_notes')
          .where('user_id', isEqualTo: userId)
          .where('contact_name', isEqualTo: widget.contactName)
          .where('contact_phone_number', isEqualTo: widget.contactPhoneNumber)
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> notes = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Add document ID for reference
        return data;
      }).toList();

      setState(() {
        callNotes = notes;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching call notes: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> addNewCallNote() async {
    if (_noteController.text.trim().isEmpty) return;

    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      CollectionReference notesRef = firestore.collection('contact_notes');

      // Create a timestamp for the current time
      Timestamp timestamp = Timestamp.now();

      // Create a map with the new note data
      Map<String, dynamic> newNoteData = {
        'user_id': userId,
        'contact_name': widget.contactName,
        'contact_phone_number': widget.contactPhoneNumber,
        'list_name': widget.listName,
        'note_text': _noteController.text.trim(),
        'timestamp': timestamp,
      };

      // Add the new document with an auto-generated ID
      await notesRef.add(newNoteData);
      
      // Clear the text field
      _noteController.clear();
      
      // Refresh the notes list
      fetchCallNotes();
      
      print('New call note added successfully!');
    } catch (e) {
      print('Error adding new call note to Firestore: $e');
    }
  }

  Future<void> deleteNote(String noteId) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      await firestore.collection('contact_notes').doc(noteId).delete();
      
      // Refresh the notes list
      fetchCallNotes();
      
      print('Note deleted successfully!');
    } catch (e) {
      print('Error deleting note: $e');
    }
  }

  String formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return DateFormat('MMM d, yyyy - h:mm a').format(dateTime);
  }
  
  // Method to show edit note dialog
  Future<void> _showEditNoteDialog(String noteId, String currentText) async {
    final TextEditingController editController = TextEditingController(text: currentText);
    
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Note'),
          content: TextField(
            controller: editController,
            decoration: const InputDecoration(
              hintText: 'Edit your note...',
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () async {
                // Update the note in Firebase
                if (editController.text.trim().isNotEmpty) {
                  try {
                    FirebaseFirestore firestore = FirebaseFirestore.instance;
                    await firestore.collection('contact_notes').doc(noteId).update({
                      'note_text': editController.text.trim(),
                      'edited_at': Timestamp.now(), // Optional: track when the note was edited
                    });
                    
                    // Refresh the notes list
                    fetchCallNotes();
                    
                    print('Note updated successfully!');
                  } catch (e) {
                    print('Error updating note: $e');
                  }
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notes for ${widget.contactName}'),
      ),
      body: Column(
        children: [
          // Contact info card
          Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contactName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Phone: ${widget.contactPhoneNumber}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'List: ${widget.listName}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Add new note section
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      hintText: 'Add a note about this call...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: addNewCallNote,
                  child: const Text('Add Note'),
                ),
              ],
            ),
          ),
          
          // Notes list
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : callNotes.isEmpty
                    ? const Center(child: Text('No notes yet. Add your first note!'))
                    : ListView.builder(
                        itemCount: callNotes.length,
                        itemBuilder: (context, index) {
                          final note = callNotes[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        formatTimestamp(note['timestamp']),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 20),
                                        onPressed: () => deleteNote(note['id']),
                                        color: Colors.red[300],
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () {
                                      // Show edit dialog when note is tapped
                                      _showEditNoteDialog(note['id'], note['note_text']);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(4.0),
                                      ),
                                  child: note['note_text']?.contains('Call Feedback:') ?? false
                                      ? Text(
                                          note['note_text'],
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.blue[800],
                                            fontWeight: FontWeight.w500
                                          ),
                                        )
                                      : Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                note['note_text'],
                                                style: const TextStyle(fontSize: 16),
                                              ),
                                            ),
                                            const Icon(
                                              Icons.edit,
                                              size: 16,
                                              color: Colors.grey,
                                            ),
                                          ],
                                        ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Make a call to the contact
          final Uri launchUri = Uri(
            scheme: 'tel',
            path: widget.contactPhoneNumber,
          );
          launchUrl(launchUri);
        },
        child: const Icon(Icons.call),
        tooltip: 'Call Contact',
      ),
    );
  }
}
