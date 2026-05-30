import 'package:watch_track/data/models/movie_model.dart';
import 'package:watch_track/features/import_watchlist/domain/title_cleaner.dart';
import 'package:watch_track/features/import_watchlist/data/tmdb_import_repository.dart';

import 'package:string_similarity/string_similarity.dart';

enum MatchStatus {
  matched,
  needsReview,
  notFound,
  duplicate,
}

class MatchResult {
  final String originalTitle;
  final String cleanedTitle;
  Movie? matchedMovie;
  List<Movie> alternativeMatches;
  MatchStatus status;
  bool isSelected; // For the UI checkboxes

  MatchResult({
    required this.originalTitle,
    required this.cleanedTitle,
    this.matchedMovie,
    this.alternativeMatches = const [],
    this.status = MatchStatus.notFound,
    this.isSelected = false,
  });
}

class ImportMatcher {
  final TmdbImportRepository _repository;

  ImportMatcher(this._repository);

  /// Processes a list of raw string titles and returns a list of MatchResults.
  /// Emits progress updates via the onProgress callback.
  Future<List<MatchResult>> processTitles(
    List<String> rawTitles,
    void Function(int processed, int total) onProgress, {
    required bool Function(String tmdbId) isDuplicate,
  }) async {
    List<MatchResult> results = [];
    int total = rawTitles.length;
    int processed = 0;

    for (String raw in rawTitles) {
      String cleaned = TitleCleaner.clean(raw);
      
      MatchResult result = MatchResult(
        originalTitle: raw,
        cleanedTitle: cleaned,
      );

      if (cleaned.isNotEmpty) {
        final matches = await _repository.findBestMatches(cleaned);
        
        if (matches.isEmpty) {
          result.status = MatchStatus.notFound;
        } else {
          // Sort matches by similarity score descending
          matches.sort((a, b) {
            final scoreA = a.title.toLowerCase().similarityTo(cleaned.toLowerCase());
            final scoreB = b.title.toLowerCase().similarityTo(cleaned.toLowerCase());
            return scoreB.compareTo(scoreA); // Higher first
          });

          final bestMatch = matches.first;
          final score = bestMatch.title.toLowerCase().similarityTo(cleaned.toLowerCase());
          
          if (isDuplicate(bestMatch.id)) {
            result.matchedMovie = bestMatch;
            result.status = MatchStatus.duplicate;
            result.isSelected = false;
          } else if (score >= 0.8) {
            result.matchedMovie = bestMatch;
            result.status = MatchStatus.matched;
            result.isSelected = true;
          } else {
            // Multiple matches or low confidence, needs user review
            result.alternativeMatches = matches;
            result.matchedMovie = matches.first; // Default selection
            result.status = MatchStatus.needsReview;
            result.isSelected = false; // User should review before importing
          }
        }
      }

      results.add(result);
      processed++;
      onProgress(processed, total);
    }

    return results;
  }


}
