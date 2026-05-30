class TitleCleaner {
  /// Cleans noise from a title string to produce a better TMDB search query.
  static String clean(String input) {
    if (input.isEmpty) return '';

    String cleaned = input;

    // Remove file extensions if present
    cleaned = cleaned.replaceAll(RegExp(r'\.(mkv|mp4|avi|srt|txt|csv)$', caseSensitive: false), '');

    // Replace common separators with spaces
    cleaned = cleaned.replaceAll(RegExp(r'[._-]'), ' ');

    // Define noise patterns to remove (case insensitive)
    final noisePatterns = [
      r'\b(1080p|720p|480p|2160p|4k)\b',
      r'\b(bluray|brrip|bdrip|web-dl|webrip|hdrip|dvdrip|camrip|hdts)\b',
      r'\b(x264|x265|hevc|aac|ac3|dts)\b',
      r'\b(hindi dubbed|dual audio|multi audio)\b',
      r'\b(season\s*\d+(?:\s*-\s*\d+)?|s\d+(?:\s*-\s*s?\d+)?|episode\s*\d+|e\d+|s\d+e\d+)\b', // S01, S1-S3, Season 1, Episode 5, S01E05
      r'\b(\d+\s*-\s*\d+)\b', // 1-5 (common for movie parts)
      r'\b(complete|extended|unrated|directors cut|part \d+)\b',
      r'\[.*?\]', // Anything in square brackets [like this]
      r'\(.*?\)', // Anything in parentheses (like this).
    ];

    for (final pattern in noisePatterns) {
      cleaned = cleaned.replaceAll(RegExp(pattern, caseSensitive: false), ' ');
    }

    // Remove emojis
    cleaned = cleaned.replaceAll(RegExp(r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F900}-\u{1F9FF}\u{1FA70}-\u{1FAFF}]', unicode: true), ' ');

    // Collapse multiple spaces into one and trim
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleaned;
  }
}
