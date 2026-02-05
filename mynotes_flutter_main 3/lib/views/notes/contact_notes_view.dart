import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:flutter_application_1/services/trie/trie.dart';
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
  List<Map<String, dynamic>> filteredNotes = []; // Notes filtered by search query
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  /// Trie data structure for efficient autocomplete search
  /// Stores all words from all notes for O(k) prefix search where k = word length
  final Trie _noteTrie = Trie();
  
  /// Current search query
  String _searchQuery = '';
  
  /// Autocomplete suggestions based on current search query
  List<String> _autocompleteSuggestions = [];
  
  /// Whether to show autocomplete suggestions
  bool _showSuggestions = false;
  
  String get userId => AuthService.firebase().currentUser!.id;

  @override
  void initState() {
    super.initState();
    fetchCallNotes();
    
    // Listen to search query changes for real-time autocomplete
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _noteController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  /// Handle search query changes
  /// Updates autocomplete suggestions and filters notes in real-time
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
      _showSuggestions = _searchQuery.isNotEmpty;
      
      if (_searchQuery.isEmpty) {
        // No search query - show all notes
        filteredNotes = callNotes;
        _autocompleteSuggestions = [];
      } else {
        // Get autocomplete suggestions from Trie (O(k) time complexity)
        _autocompleteSuggestions = _noteTrie.getAutocompleteSuggestions(
          _searchQuery,
          maxSuggestions: 5,
        );
        
        // Filter notes based on search query
        // Two approaches:
        // 1. Use Trie to get document IDs (fast for prefix search)
        // 2. Fall back to full-text search for non-prefix matches
        _filterNotes();
      }
    });
  }
  
  /// Filter notes based on current search query
  /// Uses Trie for efficient prefix matching
  void _filterNotes() {
    if (_searchQuery.isEmpty) {
      filteredNotes = callNotes;
      return;
    }
    
    // Get document IDs from Trie for prefix match
    Set<String> trieMatchedIds = _noteTrie.getDocumentIdsWithPrefix(_searchQuery);
    
    // Filter notes: include if ID matches from Trie OR if text contains query
    filteredNotes = callNotes.where((note) {
      String noteId = note['id'] ?? '';
      String noteText = (note['note_text'] ?? '').toLowerCase();
      
      // Match if Trie found this document OR if text contains search query
      return trieMatchedIds.contains(noteId) || noteText.contains(_searchQuery);
    }).toList();
  }
  
  /// Build the Trie from all notes
  /// This enables fast O(k) autocomplete searches
  void _buildTrieFromNotes() {
    // Clear existing Trie
    _noteTrie.clear();
    
    // Insert all note texts into the Trie
    for (var note in callNotes) {
      String noteId = note['id'] ?? '';
      String noteText = note['note_text'] ?? '';
      
      if (noteText.isNotEmpty) {
        // Insert entire text - Trie will split into words automatically
        _noteTrie.insertText(noteText, noteId);
      }
    }
    
    print('📚 Trie built with ${_noteTrie.wordCount} unique words');
    print('📊 Trie stats: ${_noteTrie.getStats()}');
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
        
        // Debug: Print each note's data
        print('Note fetched - ID: ${doc.id}');
        print('  - rating: ${data['rating']}');
        print('  - note_text: ${data['note_text']}');
        print('  - has_feedback: ${data['has_feedback']}');
        
        return data;
      }).toList();

      setState(() {
        callNotes = notes;
        filteredNotes = notes; // Initially show all notes
        isLoading = false;
      });
      
      // Build Trie from all notes for autocomplete
      _buildTrieFromNotes();
      
      print('Total notes fetched: ${notes.length}');
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
          
          // Search bar with autocomplete (Trie-based)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search input field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search notes...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                
                // Autocomplete suggestions dropdown
                if (_showSuggestions && _autocompleteSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Suggestions:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ..._autocompleteSuggestions.map((suggestion) {
                          return InkWell(
                            onTap: () {
                              // When user taps suggestion, update search query
                              _searchController.text = suggestion;
                              setState(() {
                                _showSuggestions = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Colors.grey.shade200),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.search,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                        children: _highlightMatch(
                                          suggestion,
                                          _searchQuery,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                
                // Search results count
                if (_searchQuery.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Found ${filteredNotes.length} note${filteredNotes.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
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
          
          // Notes list (filtered by search query)
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredNotes.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No notes yet. Add your first note!'
                              : 'No notes match your search.',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredNotes.length,
                        itemBuilder: (context, index) {
                          final note = filteredNotes[index];
                          bool isCallFeedback = note['note_text']?.contains('Call Feedback:') ?? false;
                          bool hasFeedback = note['has_feedback'] == true;
                          bool hasRating = note['rating'] != null && (note['rating'] is int ? note['rating'] : int.tryParse(note['rating'].toString()) ?? 0) > 0;
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            // Add color highlight for call feedback notes
                            color: (isCallFeedback || hasFeedback) ? Colors.blue[50] : Colors.white,
                            elevation: (isCallFeedback || hasFeedback) ? 3 : 1,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              formatTimestamp(note['timestamp']),
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            // Display rating in the header if available
                                            if (note['rating'] != null && (note['rating'] is int ? note['rating'] : int.tryParse(note['rating'].toString())) != null && (note['rating'] is int ? note['rating'] : int.tryParse(note['rating'].toString()))! > 0) ...[
                                              SizedBox(height: 4),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  ...List.generate(5, (index) {
                                                    int rating = note['rating'] is int ? note['rating'] : int.tryParse(note['rating'].toString()) ?? 0;
                                                    return Icon(
                                                      index < rating ? Icons.star : Icons.star_border,
                                                      color: Colors.amber,
                                                      size: 16,
                                                    );
                                                  }),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    '${note['rating'] is int ? note['rating'] : int.tryParse(note['rating'].toString()) ?? 0}/5',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.amber[700],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
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
                                  child: _buildNoteContent(note),
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

  Widget _buildNoteContent(Map<String, dynamic> note) {
    // Check if this is a call feedback note or if it has feedback
    bool isCallFeedback = note['note_text']?.contains('Call Feedback:') ?? false;
    bool hasFeedback = note['has_feedback'] == true;
    
    // Get rating value - handle different data types
    dynamic ratingValue = note['rating'];
    int? rating;
    
    if (ratingValue != null) {
      if (ratingValue is int) {
        rating = ratingValue;
      } else if (ratingValue is String) {
        rating = int.tryParse(ratingValue);
      } else if (ratingValue is double) {
        rating = ratingValue.toInt();
      }
    }

    bool hasRating = rating != null && rating > 0;
    
    // Debug output
    print('Building note content - has_feedback: $hasFeedback, rating: $rating, hasRating: $hasRating');

    // Build the star rating widget with individual stars
    Widget ratingWidget = hasRating
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...List.generate(5, (index) {
                return Icon(
                  index < rating! ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 18,
                );
              }),
              SizedBox(width: 6),
              Text(
                '$rating/5',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber[700],
                ),
              ),
            ],
          )
        : SizedBox.shrink();

    // If it's a call feedback note or has feedback, show it differently
    if (isCallFeedback || hasFeedback) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note['note_text'] ?? 'Call initiated',
            style: TextStyle(
              fontSize: 16,
              color: isCallFeedback ? Colors.blue[800] : Colors.black87,
              fontWeight: isCallFeedback ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          if (hasRating) ...[
            SizedBox(height: 8),
            ratingWidget,
          ],
        ],
      );
    } else {
      // Regular note (not call feedback)
      return Row(
        children: [
          Expanded(
            child: Text(
              note['note_text'] ?? 'No content',
              style: const TextStyle(fontSize: 16),
            ),
          ),
          if (hasRating) ...[
            ratingWidget,
            SizedBox(width: 8),
          ],
          const Icon(
            Icons.edit,
            size: 16,
            color: Colors.grey,
          ),
        ],
      );
    }
  }
  
  /// Highlight the matching prefix in autocomplete suggestions
  /// 
  /// Creates a TextSpan with bold, colored text for the matching part
  /// and normal text for the rest of the word
  /// 
  /// Parameters:
  /// - text: The full suggestion text
  /// - query: The search query to highlight
  /// 
  /// Returns: List of TextSpan objects for RichText widget
  List<TextSpan> _highlightMatch(String text, String query) {
    if (query.isEmpty || !text.toLowerCase().startsWith(query.toLowerCase())) {
      return [TextSpan(text: text)];
    }
    
    return [
      TextSpan(
        text: text.substring(0, query.length),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
      TextSpan(
        text: text.substring(query.length),
      ),
    ];
  }
}
