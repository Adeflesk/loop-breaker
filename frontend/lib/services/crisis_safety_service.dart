/// CrisisSafetyService: Detects crisis indicators in user text using keyword matching.
///
/// Provides local, real-time crisis detection without network calls.
/// Matches backend CrisisSafetyService behavior in Python.
class CrisisSafetyService {
  /// Default crisis indicator keywords (28 total)
  static const List<String> DEFAULT_KEYWORDS = [
    'suicide',
    'kill myself',
    'kill my self',
    'end it',
    'end my life',
    'harm myself',
    'self harm',
    'self-harm',
    'cut myself',
    'cutting',
    'overdose',
    'OD',
    'take pills',
    'hopeless',
    'no point',
    'pointless',
    'give up',
    "can't go on",
    'better off dead',
    'everyone would be better without me',
    'nothing matters',
    'why bother',
    'abuse',
    'being hurt',
    'domestic violence',
    'hit me',
    'rape',
    'sexual assault',
  ];

  /// Minimum text length to analyze (chars < this are skipped)
  static const int MIN_TEXT_LENGTH = 10;

  /// Keywords to search for (may be customized or use defaults)
  final List<String> keywords;

  /// Constructor with optional custom keywords
  /// If customKeywords is null or empty, uses DEFAULT_KEYWORDS.
  CrisisSafetyService({List<String>? customKeywords})
      : keywords = (customKeywords != null && customKeywords.isNotEmpty)
            ? customKeywords
            : DEFAULT_KEYWORDS;

  /// Detects crisis indicators in the given text.
  ///
  /// Returns a tuple (is_crisis, detected_keywords):
  /// - is_crisis: bool, true if any crisis keywords detected
  /// - detected_keywords: List<String>, deduped keywords found (empty if none)
  ///
  /// Skips analysis if:
  /// - text is null or empty
  /// - text length < MIN_TEXT_LENGTH
  ///
  /// Matching is case-insensitive with word boundaries.
  (bool, List<String>) detectCrisis(String? text) {
    // Handle null or empty input
    if (text == null || text.isEmpty) {
      return (false, []);
    }

    // Skip if text is too short (avoid accidental matches)
    if (text.length < MIN_TEXT_LENGTH) {
      return (false, []);
    }

    // Convert to lowercase for case-insensitive matching
    final lowerText = text.toLowerCase();

    // Collect matched keywords (may have duplicates)
    final matchedKeywords = <String>[];

    // Search for each keyword with word boundaries
    for (final keyword in keywords) {
      final lowerKeyword = keyword.toLowerCase();

      // Build regex pattern with word boundaries
      // \b matches at word boundaries (transition between \w and \W)
      final pattern = RegExp(r'\b' + RegExp.escape(lowerKeyword) + r'\b');

      if (pattern.hasMatch(lowerText)) {
        matchedKeywords.add(keyword);
      }
    }

    // Deduplicate keywords and return
    final deduped = matchedKeywords.toSet().toList();
    final isCrisis = deduped.isNotEmpty;

    return (isCrisis, deduped);
  }

  /// Convenience method: checks if text contains crisis indicators (boolean only)
  bool isCrisis(String? text) {
    final (isCrisis, _) = detectCrisis(text);
    return isCrisis;
  }

  /// Convenience method: gets detected keywords as a list (empty if none)
  List<String> getDetectedKeywords(String? text) {
    final (_, keywords) = detectCrisis(text);
    return keywords;
  }
}
