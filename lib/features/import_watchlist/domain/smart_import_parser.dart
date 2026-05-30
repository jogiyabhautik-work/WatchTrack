class SmartImportParser {
  /// Parses a messy multi-line string into a list of clean raw titles.
  static List<String> parsePastedText(String text) {
    if (text.trim().isEmpty) return [];

    final lines = text.split(RegExp(r'\r?\n'));
    final List<String> extracted = [];

    // Metadata keywords to ignore completely
    final ignoreKeywords = [
      'where to watch',
      'hindi available',
      'watched',
      'status',
      'rating',
      'review',
      'my list',
      'favorites',
    ];

    for (var line in lines) {
      String current = line.trim();

      // Skip empty lines
      if (current.isEmpty) continue;

      // Check if it's a metadata line
      bool isMetadata = false;
      for (final keyword in ignoreKeywords) {
        if (current.toLowerCase().startsWith(keyword)) {
          isMetadata = true;
          break;
        }
      }
      if (isMetadata) continue;

      // Extract title from numbered list (e.g., "1. Oppenheimer" or "35.dude" or "1) Movie")
      // RegExp explanation: optional whitespace, digits, optional dot/parenthesis, optional whitespace
      final match = RegExp(r'^\s*\d+[\.\)]?\s*(.*)$').firstMatch(current);
      if (match != null) {
        current = match.group(1) ?? '';
      }

      // Sometimes people put multiple items separated by commas or hyphens without numbers,
      // but usually numbered lists have one per line. If we want to split "housefull 1-5" 
      // into multiple, it's better to just keep it as "housefull 1-5" and let the TitleCleaner 
      // reduce it to "housefull" so TMDB finds the franchise or first movie, and the user 
      // can review it.

      current = current.trim();
      if (current.isNotEmpty && current.length > 1) { // Ignore single-character noise
        extracted.add(current);
      }
    }

    // Deduplicate
    return extracted.toSet().toList();
  }
}
