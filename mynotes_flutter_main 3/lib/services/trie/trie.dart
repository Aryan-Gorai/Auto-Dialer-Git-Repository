/// Trie Node - represents a single character in the Trie tree
/// Each node contains:
/// - A map of children nodes (character -> TrieNode)
/// - A boolean flag to mark end of a word
/// - A set of document IDs where this word appears (for efficient note lookup)
class TrieNode {
  /// Map of children nodes: key = character, value = TrieNode
  Map<String, TrieNode> children = {};
  
  /// Flag to mark if this node represents the end of a complete word
  bool isEndOfWord = false;
  
  /// Set of document IDs (Firebase note IDs) where this word appears
  /// This allows us to quickly find which notes contain a searched word
  Set<String> documentIds = {};
  
  /// Frequency count - how many times this word appears across all notes
  int frequency = 0;
}

/// Trie Data Structure for efficient autocomplete and prefix search
/// 
/// Time Complexity:
/// - Insert: O(k) where k = length of word
/// - Search: O(k) where k = length of word
/// - Search with prefix: O(k + n) where k = prefix length, n = number of matches
/// 
/// Space Complexity: O(ALPHABET_SIZE * N * M) 
/// where N = number of words, M = average word length
/// 
/// Use Case: Fast autocomplete when searching through contact notes
/// The Trie stores all words from all notes, making prefix-based searches very efficient
class Trie {
  /// Root node of the Trie - represents an empty string
  final TrieNode root = TrieNode();
  
  /// Total number of unique words in the Trie
  int _wordCount = 0;
  
  /// Get the total number of unique words
  int get wordCount => _wordCount;
  
  /// Insert a word into the Trie with the associated document ID
  /// 
  /// This method:
  /// 1. Converts the word to lowercase for case-insensitive search
  /// 2. Traverses/creates nodes for each character in the word
  /// 3. Marks the last node as end of word
  /// 4. Associates the document ID with this word
  /// 
  /// Time Complexity: O(k) where k = word length
  /// 
  /// Parameters:
  /// - word: The word to insert
  /// - documentId: The Firebase document ID where this word appears
  void insert(String word, String documentId) {
    if (word.isEmpty) return;
    
    // Normalize: convert to lowercase and trim whitespace
    word = word.toLowerCase().trim();
    if (word.isEmpty) return;
    
    TrieNode current = root;
    
    // Traverse through each character in the word
    for (int i = 0; i < word.length; i++) {
      String char = word[i];
      
      // If character node doesn't exist, create it
      if (!current.children.containsKey(char)) {
        current.children[char] = TrieNode();
      }
      
      // Move to the next node
      current = current.children[char]!;
    }
    
    // Mark the end of the word
    if (!current.isEndOfWord) {
      current.isEndOfWord = true;
      _wordCount++;
    }
    
    // Add this document ID to the word's document set
    current.documentIds.add(documentId);
    current.frequency++;
  }
  
  /// Insert an entire text/note into the Trie
  /// 
  /// This method:
  /// 1. Splits the text into individual words
  /// 2. Inserts each word into the Trie
  /// 3. Associates all words with the same document ID
  /// 
  /// Time Complexity: O(n * k) where n = number of words, k = average word length
  /// 
  /// Parameters:
  /// - text: The complete text to index (e.g., a note's content)
  /// - documentId: The Firebase document ID for this note
  void insertText(String text, String documentId) {
    if (text.isEmpty) return;
    
    // Split text into words (by spaces, newlines, and common punctuation)
    // Remove empty strings and normalize
    List<String> words = text
        .toLowerCase()
        .split(RegExp(r'[\s\n\r,.:;!?()"\[\]{}]+'))
        .where((word) => word.isNotEmpty)
        .toList();
    
    // Insert each word individually
    for (String word in words) {
      insert(word, documentId);
    }
  }
  
  /// Search for a complete word in the Trie
  /// 
  /// Returns true if the word exists as a complete word (not just a prefix)
  /// 
  /// Time Complexity: O(k) where k = word length
  /// 
  /// Parameters:
  /// - word: The word to search for
  /// 
  /// Returns: true if word exists, false otherwise
  bool search(String word) {
    word = word.toLowerCase().trim();
    if (word.isEmpty) return false;
    
    TrieNode? node = _findNode(word);
    return node != null && node.isEndOfWord;
  }
  
  /// Check if any word in the Trie starts with the given prefix
  /// 
  /// Time Complexity: O(k) where k = prefix length
  /// 
  /// Parameters:
  /// - prefix: The prefix to search for
  /// 
  /// Returns: true if at least one word starts with this prefix
  bool startsWith(String prefix) {
    prefix = prefix.toLowerCase().trim();
    if (prefix.isEmpty) return false;
    
    return _findNode(prefix) != null;
  }
  
  /// Get all document IDs that contain words starting with the given prefix
  /// 
  /// This is the core autocomplete function - it returns all notes that contain
  /// words matching the search prefix
  /// 
  /// Time Complexity: O(k + n) where k = prefix length, n = number of matching documents
  /// 
  /// Parameters:
  /// - prefix: The search prefix
  /// 
  /// Returns: Set of document IDs containing words with this prefix
  Set<String> getDocumentIdsWithPrefix(String prefix) {
    prefix = prefix.toLowerCase().trim();
    if (prefix.isEmpty) return {};
    
    TrieNode? node = _findNode(prefix);
    if (node == null) return {};
    
    // Collect all document IDs from this node and all its descendants
    Set<String> documentIds = {};
    _collectDocumentIds(node, documentIds);
    
    return documentIds;
  }
  
  /// Get autocomplete suggestions for a given prefix
  /// 
  /// Returns a list of words that start with the prefix, sorted by frequency
  /// 
  /// Time Complexity: O(k + n * m) where k = prefix length, 
  ///                  n = number of suggestions, m = average word length
  /// 
  /// Parameters:
  /// - prefix: The search prefix
  /// - maxSuggestions: Maximum number of suggestions to return (default: 10)
  /// 
  /// Returns: List of suggested words, sorted by frequency (most common first)
  List<String> getAutocompleteSuggestions(String prefix, {int maxSuggestions = 10}) {
    prefix = prefix.toLowerCase().trim();
    if (prefix.isEmpty) return [];
    
    TrieNode? node = _findNode(prefix);
    if (node == null) return [];
    
    // Collect all words with this prefix
    List<Map<String, dynamic>> suggestions = [];
    _collectWords(node, prefix, suggestions);
    
    // Sort by frequency (descending) and then alphabetically
    suggestions.sort((a, b) {
      int freqCompare = (b['frequency'] as int).compareTo(a['frequency'] as int);
      if (freqCompare != 0) return freqCompare;
      return (a['word'] as String).compareTo(b['word'] as String);
    });
    
    // Return top N suggestions
    return suggestions
        .take(maxSuggestions)
        .map((item) => item['word'] as String)
        .toList();
  }
  
  /// Find the node representing the end of a given prefix/word
  /// 
  /// Private helper method for traversing the Trie
  /// 
  /// Time Complexity: O(k) where k = word/prefix length
  /// 
  /// Parameters:
  /// - word: The word or prefix to find
  /// 
  /// Returns: TrieNode if found, null otherwise
  TrieNode? _findNode(String word) {
    TrieNode current = root;
    
    for (int i = 0; i < word.length; i++) {
      String char = word[i];
      
      if (!current.children.containsKey(char)) {
        return null; // Character not found
      }
      
      current = current.children[char]!;
    }
    
    return current;
  }
  
  /// Recursively collect all document IDs from a node and its descendants
  /// 
  /// Private helper method for getting all notes that match a prefix
  /// 
  /// Parameters:
  /// - node: The starting node
  /// - documentIds: Set to collect document IDs into
  void _collectDocumentIds(TrieNode node, Set<String> documentIds) {
    // Add document IDs from current node
    documentIds.addAll(node.documentIds);
    
    // Recursively collect from children
    for (TrieNode child in node.children.values) {
      _collectDocumentIds(child, documentIds);
    }
  }
  
  /// Recursively collect all words from a node and its descendants
  /// 
  /// Private helper method for autocomplete suggestions
  /// 
  /// Parameters:
  /// - node: The starting node
  /// - currentWord: The word built so far
  /// - words: List to collect word suggestions into
  void _collectWords(TrieNode node, String currentWord, List<Map<String, dynamic>> words) {
    // If this is the end of a word, add it to suggestions
    if (node.isEndOfWord) {
      words.add({
        'word': currentWord,
        'frequency': node.frequency,
        'documentCount': node.documentIds.length,
      });
    }
    
    // Recursively collect words from children
    for (var entry in node.children.entries) {
      _collectWords(entry.value, currentWord + entry.key, words);
    }
  }
  
  /// Clear the entire Trie
  /// 
  /// Removes all words and resets the data structure
  void clear() {
    root.children.clear();
    _wordCount = 0;
  }
  
  /// Get statistics about the Trie
  /// 
  /// Returns a map with useful information about the Trie's contents
  Map<String, dynamic> getStats() {
    int totalNodes = _countNodes(root);
    
    return {
      'unique_words': _wordCount,
      'total_nodes': totalNodes,
      'memory_efficient': _wordCount > 0 ? (totalNodes / _wordCount).toStringAsFixed(2) : '0',
    };
  }
  
  /// Count total number of nodes in the Trie
  /// 
  /// Private helper method for statistics
  int _countNodes(TrieNode node) {
    int count = 1; // Count this node
    
    for (TrieNode child in node.children.values) {
      count += _countNodes(child);
    }
    
    return count;
  }
}
