import 'dart:math';

/// NLP Service for text analysis and note summarization
/// 
/// Implements key Natural Language Processing techniques:
/// 1. Tokenization - Split text into words
/// 2. Stop word removal - Remove common unimportant words
/// 3. Stemming - Reduce words to root form
/// 4. TF-IDF - Calculate word importance across documents
/// 5. N-gram analysis - Find common phrase patterns
/// 6. Word frequency - Count occurrence of each word
/// 
/// Use case: Generate intelligent summaries of contact notes
class NLPService {
  /// Common English stop words to filter out
  /// These are words that don't carry significant meaning
  static const Set<String> _stopWords = {
    'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
    'of', 'with', 'by', 'from', 'up', 'about', 'into', 'through', 'during',
    'before', 'after', 'above', 'below', 'between', 'under', 'again',
    'further', 'then', 'once', 'here', 'there', 'when', 'where', 'why',
    'how', 'all', 'both', 'each', 'few', 'more', 'most', 'other', 'some',
    'such', 'no', 'nor', 'not', 'only', 'own', 'same', 'so', 'than',
    'too', 'very', 's', 't', 'can', 'will', 'just', 'don', 'should', 'now',
    'i', 'me', 'my', 'myself', 'we', 'our', 'ours', 'ourselves', 'you',
    'your', 'yours', 'yourself', 'yourselves', 'he', 'him', 'his', 'himself',
    'she', 'her', 'hers', 'herself', 'it', 'its', 'itself', 'they', 'them',
    'their', 'theirs', 'themselves', 'what', 'which', 'who', 'whom', 'this',
    'that', 'these', 'those', 'am', 'is', 'are', 'was', 'were', 'be', 'been',
    'being', 'have', 'has', 'had', 'having', 'do', 'does', 'did', 'doing',
    // Call-specific stop words
    'call', 'called', 'calling', 'initiated', 'feedback', 'answered',
    'rating', 'duration', 'seconds', 'yes', 'left', 'voicemail',
  };
  
  /// Simple stemming rules for common word endings
  /// Maps word endings to their replacements (root forms)
  static const Map<String, String> _stemmingRules = {
    'ing': '',      // calling → call
    'ed': '',       // called → call
    'er': '',       // caller → call
    'est': '',      // fastest → fast
    'ly': '',       // quickly → quick
    'ness': '',     // happiness → happy
    'ment': '',     // payment → pay
    'tion': '',     // action → act
    'sion': '',     // decision → decis
    'ance': '',     // performance → perform
    'ence': '',     // difference → differ
    'able': '',     // readable → read
    'ible': '',     // possible → poss
    'ful': '',      // helpful → help
    'less': '',     // helpless → help
    'ous': '',      // dangerous → danger
    'ive': '',      // active → act
    's': '',        // calls → call (simple plural)
  };
  
  /// Tokenization: Split text into individual words
  /// 
  /// Process:
  /// 1. Convert to lowercase for consistency
  /// 2. Split on whitespace, punctuation, and special characters
  /// 3. Remove empty tokens
  /// 
  /// Time Complexity: O(n) where n = text length
  /// 
  /// Example: "Call John at 3pm!" → ["call", "john", "at", "3pm"]
  static List<String> tokenize(String text) {
    if (text.isEmpty) return [];
    
    // Convert to lowercase and split on non-alphanumeric characters
    // Keep numbers as they might be important (phone numbers, times, etc.)
    return text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toList();
  }
  
  /// Remove stop words from token list
  /// 
  /// Filters out common words that don't carry significant meaning
  /// This helps focus on the important content words
  /// 
  /// Time Complexity: O(n) where n = number of tokens
  /// 
  /// Example: ["call", "the", "client"] → ["client"]
  static List<String> removeStopWords(List<String> tokens) {
    return tokens.where((token) => !_stopWords.contains(token)).toList();
  }
  
  /// Stem words to their root form
  /// 
  /// Uses simple suffix stripping rules
  /// More sophisticated than just removing endings - checks minimum word length
  /// 
  /// Time Complexity: O(n * m) where n = tokens, m = average word length
  /// 
  /// Example: ["calling", "called", "caller"] → ["call", "call", "call"]
  static List<String> stem(List<String> tokens) {
    return tokens.map((token) {
      // Don't stem very short words (likely to be root forms already)
      if (token.length <= 3) return token;
      
      // Try each stemming rule
      for (var entry in _stemmingRules.entries) {
        String suffix = entry.key;
        String replacement = entry.value;
        
        if (token.endsWith(suffix)) {
          String stemmed = token.substring(0, token.length - suffix.length) + replacement;
          // Only use stemmed version if it's at least 2 characters
          if (stemmed.length >= 2) {
            return stemmed;
          }
        }
      }
      
      return token;
    }).toList();
  }
  
  /// Calculate word frequency using a hash table
  /// 
  /// Time Complexity: O(n) where n = number of tokens
  /// Space Complexity: O(k) where k = unique words
  /// 
  /// Returns: Map of word → count
  static Map<String, int> calculateWordFrequency(List<String> tokens) {
    Map<String, int> frequency = {};
    
    for (String token in tokens) {
      frequency[token] = (frequency[token] ?? 0) + 1;
    }
    
    return frequency;
  }
  
  /// Generate n-grams (sequences of n words)
  /// 
  /// N-grams help identify common phrases and patterns
  /// 
  /// Time Complexity: O(n * m) where n = tokens, m = n-gram size
  /// 
  /// Example with n=2: ["need", "call", "back"] → ["need call", "call back"]
  static List<String> generateNGrams(List<String> tokens, int n) {
    if (tokens.length < n) return [];
    
    List<String> ngrams = [];
    for (int i = 0; i <= tokens.length - n; i++) {
      String ngram = tokens.sublist(i, i + n).join(' ');
      ngrams.add(ngram);
    }
    
    return ngrams;
  }
  
  /// Calculate TF-IDF (Term Frequency-Inverse Document Frequency)
  /// 
  /// TF-IDF measures how important a word is to a document in a collection
  /// Higher score = more important/distinctive word
  /// 
  /// Formula:
  /// TF(t,d) = (Number of times term t appears in document d) / (Total terms in d)
  /// IDF(t) = log(Total documents / Documents containing t)
  /// TF-IDF = TF * IDF
  /// 
  /// Time Complexity: O(n * m) where n = documents, m = average words per doc
  /// 
  /// Returns: Map of word → TF-IDF score
  static Map<String, double> calculateTFIDF(
    List<List<String>> documents,
    int documentIndex,
  ) {
    if (documents.isEmpty || documentIndex >= documents.length) {
      return {};
    }
    
    List<String> currentDoc = documents[documentIndex];
    int totalDocs = documents.length;
    
    // Calculate term frequency for current document
    Map<String, int> termFreq = calculateWordFrequency(currentDoc);
    int totalTerms = currentDoc.length;
    
    // Calculate document frequency (how many docs contain each term)
    Map<String, int> docFreq = {};
    for (String term in termFreq.keys) {
      int count = 0;
      for (List<String> doc in documents) {
        if (doc.contains(term)) {
          count++;
        }
      }
      docFreq[term] = count;
    }
    
    // Calculate TF-IDF for each term
    Map<String, double> tfidf = {};
    for (String term in termFreq.keys) {
      double tf = termFreq[term]! / totalTerms;
      double idf = log(totalDocs / (docFreq[term] ?? 1));
      tfidf[term] = tf * idf;
    }
    
    return tfidf;
  }
  
  /// Extract top keywords from text using TF-IDF
  /// 
  /// This is useful for summarization and tagging
  /// 
  /// Parameters:
  /// - documents: All note texts to analyze
  /// - topN: Number of keywords to extract
  /// 
  /// Returns: List of top keywords sorted by importance
  static List<String> extractKeywords(List<String> documents, {int topN = 5}) {
    if (documents.isEmpty) return [];
    
    // Process all documents
    List<List<String>> processedDocs = documents.map((doc) {
      List<String> tokens = tokenize(doc);
      tokens = removeStopWords(tokens);
      tokens = stem(tokens);
      return tokens;
    }).toList();
    
    // Calculate TF-IDF for all documents and aggregate scores
    Map<String, double> aggregatedScores = {};
    
    for (int i = 0; i < processedDocs.length; i++) {
      Map<String, double> tfidf = calculateTFIDF(processedDocs, i);
      
      for (var entry in tfidf.entries) {
        aggregatedScores[entry.key] = 
            (aggregatedScores[entry.key] ?? 0.0) + entry.value;
      }
    }
    
    // Sort by score and return top N
    List<MapEntry<String, double>> sorted = aggregatedScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.take(topN).map((e) => e.key).toList();
  }
  
  /// Find most common n-grams (phrases) across all documents
  /// 
  /// Identifies frequently occurring multi-word phrases
  /// 
  /// Parameters:
  /// - documents: All note texts
  /// - n: Size of n-grams (2 = bigrams, 3 = trigrams)
  /// - topN: Number of top phrases to return
  /// 
  /// Returns: List of most common phrases
  static List<String> findCommonPhrases(
    List<String> documents, {
    int n = 2,
    int topN = 5,
  }) {
    if (documents.isEmpty) return [];
    
    Map<String, int> phraseFreq = {};
    
    for (String doc in documents) {
      List<String> tokens = tokenize(doc);
      tokens = removeStopWords(tokens);
      
      List<String> ngrams = generateNGrams(tokens, n);
      
      for (String ngram in ngrams) {
        phraseFreq[ngram] = (phraseFreq[ngram] ?? 0) + 1;
      }
    }
    
    // Filter out phrases that appear only once
    phraseFreq.removeWhere((key, value) => value < 2);
    
    // Sort by frequency
    List<MapEntry<String, int>> sorted = phraseFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.take(topN).map((e) => e.key).toList();
  }
  
  /// Generate a comprehensive summary of notes
  /// 
  /// Combines multiple NLP techniques:
  /// 1. Extract top keywords (using TF-IDF)
  /// 2. Find common phrases (using n-grams)
  /// 3. Calculate word frequency for context
  /// 
  /// Time Complexity: O(n * m) where n = notes, m = average note length
  /// 
  /// Parameters:
  /// - notes: List of all note texts for a contact
  /// 
  /// Returns: Structured summary map with keywords, phrases, and stats
  static Map<String, dynamic> generateNoteSummary(List<String> notes) {
    if (notes.isEmpty) {
      return {
        'keywords': [],
        'common_phrases': [],
        'total_notes': 0,
        'total_words': 0,
        'summary_text': 'No previous notes available.',
      };
    }
    
    // Extract keywords using TF-IDF
    List<String> keywords = extractKeywords(notes, topN: 5);
    
    // Find common bigrams (2-word phrases)
    List<String> bigrams = findCommonPhrases(notes, n: 2, topN: 3);
    
    // Find common trigrams (3-word phrases) if we have enough data
    List<String> trigrams = notes.length > 2 
        ? findCommonPhrases(notes, n: 3, topN: 2) 
        : [];
    
    // Calculate overall word frequency
    List<String> allTokens = [];
    for (String note in notes) {
      List<String> tokens = tokenize(note);
      tokens = removeStopWords(tokens);
      tokens = stem(tokens);
      allTokens.addAll(tokens);
    }
    
    Map<String, int> wordFreq = calculateWordFrequency(allTokens);
    
    // Get top frequent words (excluding those already in keywords)
    List<MapEntry<String, int>> freqSorted = wordFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    List<String> topWords = freqSorted
        .take(10)
        .map((e) => '${e.key} (${e.value}x)')
        .toList();
    
    // Generate human-readable summary text
    StringBuffer summaryText = StringBuffer();
    
    if (keywords.isNotEmpty) {
      summaryText.write('Key topics: ${keywords.join(", ")}. ');
    }
    
    if (bigrams.isNotEmpty) {
      summaryText.write('Common phrases: ${bigrams.join(", ")}. ');
    }
    
    if (trigrams.isNotEmpty) {
      summaryText.write('Important contexts: ${trigrams.join(", ")}. ');
    }
    
    summaryText.write('Total: ${notes.length} note${notes.length == 1 ? '' : 's'}, ${allTokens.length} words.');
    
    return {
      'keywords': keywords,
      'common_phrases': [...bigrams, ...trigrams],
      'top_words': topWords,
      'total_notes': notes.length,
      'total_words': allTokens.length,
      'summary_text': summaryText.toString().trim(),
    };
  }
  
  /// Generate a concise one-line summary (for UI display)
  /// 
  /// Creates a brief, actionable summary perfect for showing in dialogs
  /// 
  /// Parameters:
  /// - notes: List of note texts
  /// 
  /// Returns: Short summary string
  static String generateBriefSummary(List<String> notes) {
    if (notes.isEmpty) return 'No previous notes.';
    
    Map<String, dynamic> summary = generateNoteSummary(notes);
    List<String> keywords = summary['keywords'] as List<String>;
    List<String> phrases = summary['common_phrases'] as List<String>;
    
    if (keywords.isEmpty && phrases.isEmpty) {
      return '${notes.length} previous note${notes.length == 1 ? '' : 's'}.';
    }
    
    StringBuffer brief = StringBuffer();
    
    if (keywords.isNotEmpty) {
      brief.write(keywords.take(3).join(', '));
    }
    
    if (phrases.isNotEmpty && keywords.length < 3) {
      if (brief.isNotEmpty) brief.write(' • ');
      brief.write(phrases.first);
    }
    
    return brief.toString();
  }
}
