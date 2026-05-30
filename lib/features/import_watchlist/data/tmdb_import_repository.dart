import 'package:watch_track/back-end/api_service.dart';
import 'package:watch_track/data/models/movie_model.dart';

class TmdbImportRepository {
  final ApiService _apiService;

  TmdbImportRepository(this._apiService);

  /// Searches TMDB using the Multi Search endpoint and returns a sorted list of matches.
  Future<List<Movie>> findBestMatches(String query) async {
    // Attempt multi-search
    final results = await _apiService.search(query, type: 'All');
    
    if (results.isEmpty) return [];

    // Filter out people or unwanted types
    final validResults = results.where((m) => !m.genres.contains('Person') && m.title.isNotEmpty).toList();

    if (validResults.isEmpty) return [];

    // Return up to 5 results for alternatives
    return validResults.take(5).toList();
  }
}
