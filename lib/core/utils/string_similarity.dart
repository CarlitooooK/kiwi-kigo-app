class StringSimilarity {
  /// Calculates similarity focusing on partial name matches (Mexican style).
  static double compare(String? formName, String? idName) {
    if (formName == null || idName == null) return 0.0;
    
    final fWords = formName.toUpperCase().trim().split(RegExp(r'\s+')).where((w) => w.length > 1).toList();
    final iWords = idName.toUpperCase().trim().split(RegExp(r'\s+')).where((w) => w.length > 1).toList();
    
    if (fWords.isEmpty || iWords.isEmpty) return 0.0;

    int matches = 0;
    for (var fw in fWords) {
      if (iWords.contains(fw)) {
        matches++;
      }
    }

    // 1. Perfect match: all words in form are in ID and counts match
    if (matches == fWords.length && fWords.length == iWords.length) {
      return 1.0;
    }
    
    // 2. Good match: User put partial name (e.g. "Miguel Gonzalez" vs "Miguel Angel Gonzalez Flores")
    // If at least 2 words match, it's a solid identification.
    if (matches >= 2) {
      return 0.85;
    }

    // 3. Weak match: Only one word matches (e.g. only one surname)
    if (matches == 1) {
      return 0.4;
    }

    return 0.0;
  }
}
