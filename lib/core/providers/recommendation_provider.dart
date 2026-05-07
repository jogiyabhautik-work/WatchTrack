import 'package:flutter/material.dart';
import 'package:watch_track/back-end/api_service.dart';
import 'package:watch_track/core/providers/user_data_provider.dart';
import 'package:watch_track/core/providers/tracking_provider.dart';
import 'package:watch_track/data/models/movie_model.dart';
import 'package:watch_track/data/models/user_title_model.dart';

class RecommendationProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<Movie> _becauseYouWatched = [];
  List<Movie> _topPicks = [];
  List<Movie> _continueWatching = [];
  List<Movie> _hiddenGems = [];
  List<Movie> _trendingNow = [];

  bool _isLoading = false;
  String? _lastActivityHash;

  List<Movie> get becauseYouWatched => _becauseYouWatched;
  List<Movie> get topPicks => _topPicks;
  List<Movie> get continueWatching => _continueWatching;
  List<Movie> get hiddenGems => _hiddenGems;
  List<Movie> get trendingNow => _trendingNow;
  bool get isLoading => _isLoading;

  Future<void> refreshRecommendations(UserDataProvider userData, TrackingProvider tracking, {bool force = false}) async {
    final activityHash = _generateActivityHash(userData, tracking);
    if (!force && _lastActivityHash == activityHash) return;
    
    _isLoading = true;
    Future.microtask(() => notifyListeners());

    try {
      final globalSeenIds = <String>{};
      
      await _fetchTrending(globalSeenIds, force: force);
      await _fetchBecauseYouWatched(tracking, globalSeenIds, force: force);
      await _fetchTopPicks(userData, tracking, globalSeenIds, force: force);
      await _fetchContinueWatching(tracking);
      await _fetchHiddenGems(globalSeenIds, force: force);
      
      _lastActivityHash = activityHash;
    } catch (e) {
      debugPrint('Error fetching recommendations: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _generateActivityHash(UserDataProvider userData, TrackingProvider tracking) {
    return '${tracking.trackedTitles.length}-${tracking.trackedTitles.values.where((t) => t.status == TrackingStatus.watched).length}';
  }

  Future<void> _fetchBecauseYouWatched(TrackingProvider tracking, Set<String> globalSeenIds, {bool force = false}) async {
    final history = tracking.trackedTitles.values
        .where((t) => t.status == TrackingStatus.watched || t.status == TrackingStatus.watching)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (history.isEmpty) {
      _becauseYouWatched = [];
      return;
    }

    final lastWatched = history.take(5).toList();
    final List<Movie> recs = [];
    final seenIds = <String>{};

    for (var title in lastWatched) {
      final movieRecs = await _apiService.getRecommendations(title.tmdbId.toString(), isMovie: title.mediaType == 'movie', forceRefresh: force);
      for (var rec in movieRecs) {
        final isAlreadyTracked = tracking.getTracking(int.tryParse(rec.id) ?? 0) != null;
        if (!seenIds.contains(rec.id) && !globalSeenIds.contains(rec.id) && !isAlreadyTracked) {
          recs.add(rec);
          seenIds.add(rec.id);
          globalSeenIds.add(rec.id);
        }
      }
      if (recs.length >= 20) break;
    }

    // Note: userData still used for scoring in _scoreAndSort if we keep it there
    // For now we'll pass it if needed or refactor scoring too.
  }

  Future<void> _fetchTopPicks(UserDataProvider userData, TrackingProvider tracking, Set<String> globalSeenIds, {bool force = false}) async {
    final history = tracking.trackedTitles.values.where((t) => t.status == TrackingStatus.watched).toList();
    
    // If cold start, use trending + top rated
    if (history.isEmpty && userData.favoriteGenres.isEmpty) {
      _topPicks = _trendingNow.reversed.take(15).toList();
      return;
    }

    // Discover based on favorite genres
    final List<Movie> candidates = [];
    final seenIds = <String>{};

    for (var genre in userData.favoriteGenres.take(3)) {
      final genreMovies = await _apiService.getMoviesByGenre(genre, forceRefresh: force);
      for (var m in genreMovies) {
        final isAlreadyTracked = tracking.getTracking(int.tryParse(m.id) ?? 0) != null;
        if (!seenIds.contains(m.id) && !globalSeenIds.contains(m.id) && !isAlreadyTracked) {
          candidates.add(m);
          seenIds.add(m.id);
          globalSeenIds.add(m.id);
        }
      }
    }

    _topPicks = _scoreAndSort(candidates, userData).take(15).toList();
  }

  Future<void> _fetchContinueWatching(TrackingProvider tracking) async {
    final watching = tracking.trackedTitles.values
        .where((t) => t.status == TrackingStatus.watching)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final List<Movie> continueList = [];
    
    for (var title in watching) {
      // Create a Movie shell for the UI
      continueList.add(Movie(
        id: title.tmdbId.toString(),
        title: title.title,
        overview: title.overview,
        posterPath: title.posterPath,
        backdropPath: title.backdropPath,
        rating: title.userRating ?? 0.0,
        releaseDate: '',
        runtime: '',
        ageRating: '',
        genres: [],
        cast: [],
        isMovie: title.mediaType == 'movie',
      ));
    }
    
    _continueWatching = continueList;
  }

  Future<void> _fetchHiddenGems(Set<String> globalSeenIds, {bool force = false}) async {
    final topRated = await _apiService.getTopRated(forceRefresh: force);
    
    _hiddenGems = topRated.where((m) => m.rating > 8.0 && !globalSeenIds.contains(m.id)).toList();
    _hiddenGems.shuffle();
    _hiddenGems = _hiddenGems.take(15).toList();
    for (var m in _hiddenGems) {
      globalSeenIds.add(m.id);
    }
  }

  Future<void> _fetchTrending(Set<String> globalSeenIds, {bool force = false}) async {
    final movies = await _apiService.getTrendingMovies(forceRefresh: force);
    final series = await _apiService.getTrendingSeries(forceRefresh: force);
    _trendingNow = [...movies.take(10), ...series.take(10)];
    _trendingNow.shuffle();
    for (var m in _trendingNow) {
      globalSeenIds.add(m.id);
    }
  }

  List<Movie> _scoreAndSort(List<Movie> movies, UserDataProvider userData) {
    return movies..sort((a, b) {
      double scoreA = _calculateScore(a, userData);
      double scoreB = _calculateScore(b, userData);
      return scoreB.compareTo(scoreA);
    });
  }

  double _calculateScore(Movie movie, UserDataProvider userData) {
    double score = 0;

    // Genre match
    int genreMatches = movie.genres.where((g) => userData.favoriteGenres.contains(g)).length;
    score += genreMatches * 2.0;

    // Popularity base
    score += (movie.rating / 2.0);

    // Recency (approximate from year)
    try {
      if (movie.releaseDate.isNotEmpty) {
        int year = int.parse(movie.releaseDate.split('-').first);
        if (year >= 2023) score += 1.0;
        if (year >= 2020) score += 0.5;
      }
    } catch (_) {}

    // Diversity boost (if we had categories we'd use them, for now just basic)
    
    return score;
  }
}
