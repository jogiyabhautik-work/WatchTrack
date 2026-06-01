import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:watch_track/data/models/movie_model.dart';
import 'package:watch_track/core/cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart' show DefaultCacheManager;

class ApiService {
  static final String _apiKey = dotenv.get('TMDB_API_KEY', fallback: '');
  static const String _baseUrl = 'https://api.themoviedb.org/3';

  Future<http.Response?> _safeGet(String url) async {
    try {
      String finalUrl = url;
      // Add CORS proxy for web to bypass "Failed to fetch" / CORS issues on localhost
      if (kIsWeb) {
        finalUrl = 'https://corsproxy.io/?${Uri.encodeComponent(url)}';
      }
      return await http.get(Uri.parse(finalUrl));
    } catch (e) {
      debugPrint('ApiService Error: $e');
      return null;
    }
  }

  void _precacheImages(List<Movie> movies) {
    for (var movie in movies) {
      if (movie.posterPath.isNotEmpty) {
        DefaultCacheManager().downloadFile(movie.posterPath);
      }
      if (movie.backdropPath.isNotEmpty) {
        DefaultCacheManager().downloadFile(movie.backdropPath);
      }
    }
  }

  Future<List<Movie>> getTrendingMovies({bool forceRefresh = false}) async {
    const cacheKey = 'trending_movies';
    if (!forceRefresh) {
      final cached = await CacheManager.get(cacheKey);
      if (cached != null) {
        return (cached as List).map((item) => Movie.fromJson(item, isMovie: true)).toList();
      }
    }

    final response = await _safeGet('$_baseUrl/trending/movie/day?api_key=$_apiKey');

    if (response != null && response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> results = data['results'];
      await CacheManager.save(cacheKey, results, const Duration(hours: 6));
      final movies = results.map((item) => Movie.fromJson(item, isMovie: true)).toList();
      _precacheImages(movies);
      return movies;
    }
    return [];
  }

  Future<List<Movie>> getTrendingSeries({bool forceRefresh = false}) async {
    const cacheKey = 'trending_series';
    if (!forceRefresh) {
      final cached = await CacheManager.get(cacheKey);
      if (cached != null) {
        return (cached as List).map((item) => Movie.fromJson(item, isMovie: false)).toList();
      }
    }

    final response = await _safeGet('$_baseUrl/trending/tv/day?api_key=$_apiKey');

    if (response != null && response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> results = data['results'];
      await CacheManager.save(cacheKey, results, const Duration(hours: 6));
      final series = results.map((item) => Movie.fromJson(item, isMovie: false)).toList();
      _precacheImages(series);
      return series;
    }
    return [];
  }

  Future<List<Movie>> getTrendingAnime({int page = 1, bool forceRefresh = false}) async {
    const cacheKey = 'trending_anime';
    if (!forceRefresh) {
      final cached = await CacheManager.get(cacheKey);
      if (cached != null) {
        return (cached as List).map((item) => Movie.fromJson(item, isMovie: false)).toList();
      }
    }

    final response = await _safeGet('$_baseUrl/discover/tv?api_key=$_apiKey&with_genres=16&with_original_language=ja&sort_by=popularity.desc&page=$page');
    if (response != null && response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> results = data['results'];
      await CacheManager.save(cacheKey, results, const Duration(hours: 6));
      final anime = results.map((item) => Movie.fromJson(item, isMovie: false)).toList();
      _precacheImages(anime);
      return anime;
    }
    return [];
  }

  Future<List<Movie>> getAnimeByCategory(String category, {bool forceRefresh = false}) async {
    final cacheKey = 'anime_category_$category';
    if (!forceRefresh) {
      final cached = await CacheManager.get(cacheKey);
      if (cached != null) {
        return (cached as List).map((item) => Movie.fromJson(item, isMovie: false)).toList();
      }
    }

    String queryParams = '&with_genres=16&with_original_language=ja';
    if (category == 'Top Rated') queryParams += '&sort_by=vote_average.desc&vote_count.gte=100';
    if (category == 'Seasonal') queryParams += '&first_air_date_year=${DateTime.now().year}';
    if (category == 'Classic') queryParams += '&first_air_date.lte=2000-01-01';

    final response = await _safeGet('$_baseUrl/discover/tv?api_key=$_apiKey$queryParams');
    if (response != null && response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> results = data['results'];
      await CacheManager.save(cacheKey, results, const Duration(days: 1));
      final anime = results.map((item) => Movie.fromJson(item, isMovie: false)).toList();
      _precacheImages(anime);
      return anime;
    }
    return [];
  }

  Future<List<Movie>> search(String query, {String type = 'All', int? year, String? language}) async {
    if (query.isEmpty) return [];
    
    String endpoint = 'search/multi';
    if (type == 'Movies') endpoint = 'search/movie';
    if (type == 'TV Shows') endpoint = 'search/tv';
    if (type == 'People') endpoint = 'search/person';

    String url = '$_baseUrl/$endpoint?api_key=$_apiKey&query=${Uri.encodeComponent(query)}';
    
    if (year != null) {
      if (type == 'TV Shows') {
        url += '&first_air_date_year=$year';
      } else {
        url += '&year=$year';
      }
    }
    
    if (language != null && language != 'all') {
      url += '&with_original_language=$language';
    }

    final response = await _safeGet(url);

    if (response != null && response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> results = data['results'];
      
      var allItems = results.map<Movie>((item) {
        final mediaType = item['media_type'] ?? (type == 'Movies' ? 'movie' : (type == 'TV Shows' ? 'tv' : 'person'));
        
        // Robust person detection (some endpoints don't return media_type: person)
        if (mediaType == 'person' || item['known_for'] != null || item['gender'] != null) {
          return Movie(
            id: item['id'].toString(),
            title: item['name'] ?? '',
            overview: 'Known for: ${(item['known_for'] as List?)?.map((m) => m['title'] ?? m['name']).join(', ') ?? ''}',
            posterPath: item['profile_path'] != null
                ? 'https://image.tmdb.org/t/p/w500${item['profile_path']}'
                : '',
            backdropPath: '',
            rating: 0.0,
            releaseDate: '',
            runtime: '',
            ageRating: '',
            genres: ['Person'],
            cast: [],
            isMovie: false,
          );
        }
        return Movie.fromJson(item, isMovie: mediaType == 'movie');
      }).toList();

      // Post-filtering for specific types
      if (type == 'Anime') {
        // Anime: Animation genre + Japan as origin (usually)
        return allItems.where((m) => 
          m.genres.contains('Animation') && 
          (results.firstWhere((r) => r['id'].toString() == m.id)['original_language'] == 'ja')
        ).toList();
      }
      
      if (type == 'Cartoon') {
        // Cartoon: Animation genre + NOT Japanese (simplified)
        return allItems.where((m) => 
          m.genres.contains('Animation') && 
          (results.firstWhere((r) => r['id'].toString() == m.id)['original_language'] != 'ja')
        ).toList();
      }

      if (type == 'People') {
        return allItems.where((m) => m.genres.contains('Person')).toList();
      }

      final resultsList = allItems.where((m) => m.title.isNotEmpty).toList();
      _precacheImages(resultsList);
      return resultsList;
    }
    return [];
  }

  Future<Movie?> getMovieById(String id, {bool isMovie = true, bool forceRefresh = false}) async {
    final cacheKey = 'movie_detail_${id}_$isMovie';
    if (!forceRefresh) {
      final cached = await CacheManager.get(cacheKey);
      if (cached != null) {
        return Movie.fromJson(cached, isMovie: isMovie);
      }
    }

    final type = isMovie ? 'movie' : 'tv';
    final response = await _safeGet('$_baseUrl/$type/$id?api_key=$_apiKey&append_to_response=credits,keywords,release_dates,content_ratings,watch/providers');

    if (response != null && response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      
      // ... (Data extraction logic remains the same)
      
      // Note: Since the existing extraction logic is long and creates a new Movie object,
      // I will refactor to ensure the returned Movie object can be serialized back to JSON for caching.
      // But for now, I'll cache the RAW 'data' from API and let the extraction happen.
      // However, the extraction logic is integrated here.
      
      // [Extracted logic remains exactly as is in original but I wrap it in a variable]
      
      // Extract runtime
      String runtime = '';
      if (isMovie) {
        runtime = '${data['runtime']} min';
      } else {
        final episodes = data['episode_run_time'] as List;
        runtime = episodes.isNotEmpty ? '${episodes[0]} min' : '';
      }

      // Extract genres
      final List<dynamic> genresJson = data['genres'] ?? [];
      final List<String> genres = genresJson.map((g) => g['name'].toString()).toList();

      // Extract cast
      final List<dynamic> castJson = data['credits']?['cast'] ?? [];
      final List<Cast> cast = castJson.take(10).map((c) => Cast.fromJson(c)).toList();

      // Extract languages
      final List<dynamic> languagesJson = data['spoken_languages'] ?? [];
      final List<String> languages = languagesJson.map((l) => (l['english_name'] ?? l['name'] ?? '').toString()).toList();

      // Extract Watch Providers (US region)
      final providersData = data['watch/providers']?['results']?['US'];
      final List<WatchProvider> providers = [];
      if (providersData != null) {
        final List<dynamic> flatrate = providersData['flatrate'] ?? [];
        final List<dynamic> rent = providersData['rent'] ?? [];
        final List<dynamic> buy = providersData['buy'] ?? [];
        
        final allProviders = [...flatrate, ...rent, ...buy];
        final seenIds = <String>{};
        for (var p in allProviders) {
          final id = p['provider_id'].toString();
          if (!seenIds.contains(id)) {
            providers.add(WatchProvider.fromJson(p));
            seenIds.add(id);
          }
        }
      }

      // Age rating
      String ageRating = 'PG-13';
      if (isMovie) {
        final results = data['release_dates']?['results'] as List?;
        final usRating = results?.firstWhere((r) => r['iso_3166_1'] == 'US', orElse: () => null);
        if (usRating != null) {
          final cert = usRating['release_dates'][0]['certification'];
          if (cert != null && cert.isNotEmpty) ageRating = cert;
        }
      } else {
        final results = data['content_ratings']?['results'] as List?;
        final usRating = results?.firstWhere((r) => r['iso_3166_1'] == 'US', orElse: () => null);
        if (usRating != null) {
          final cert = usRating['rating'];
          if (cert != null && cert.isNotEmpty) ageRating = cert;
        }
      }

      // Generate Content Warnings from Keywords
      final List<ContentWarning> contentWarnings = [];
      final keywordsData = data['keywords'];
      final List? keywords = keywordsData is Map 
          ? (isMovie ? keywordsData['keywords'] : keywordsData['results']) as List?
          : null;
      if (keywords != null) {
        final List<String> kNames = keywords.map((k) => k['name'].toString().toLowerCase()).toList();
        if (kNames.any((k) => k.contains('violence') || k.contains('gore'))) contentWarnings.add(ContentWarning(category: 'Violence', description: 'Intense scenes.'));
        if (kNames.any((k) => k.contains('nudity') || k.contains('sex'))) contentWarnings.add(ContentWarning(category: 'Sexual Content', description: 'Suggestive themes.'));
      }

      // Extract seasons (TV only)
      final List<dynamic> seasonsJson = data['seasons'] ?? [];
      final List<Season> seasons = seasonsJson.map((s) => Season.fromJson(s)).toList();

      final movieBase = Movie.fromJson(data, isMovie: isMovie);
      
      final result = Movie(
        id: movieBase.id,
        title: movieBase.title,
        overview: movieBase.overview,
        posterPath: movieBase.posterPath,
        backdropPath: movieBase.backdropPath,
        rating: movieBase.rating,
        releaseDate: movieBase.releaseDate,
        runtime: runtime,
        ageRating: ageRating,
        ageRatingDescription: '',
        genres: genres,
        cast: cast,
        contentWarnings: contentWarnings,
        seasons: seasons,
        isMovie: isMovie,
        spokenLanguages: languages,
        watchProviders: providers,
      );

      // Save to cache (serialize the resulting Movie object)
      await CacheManager.save(cacheKey, result.toJson(), const Duration(days: 7));
      
      return result;
    } else {
      return null;
    }
  }

  Future<Actor?> getActorDetails(String id, {bool forceRefresh = false}) async {
    final cacheKey = 'actor_detail_$id';
    if (!forceRefresh) {
      final cached = await CacheManager.get(cacheKey);
      if (cached != null) {
        // Actor model needs a credits list, we can store it in the same cache
        return Actor.fromJson(cached, (cached['credits'] as List).map((m) => Movie.fromJson(m)).toList());
      }
    }

    final response = await _safeGet('$_baseUrl/person/$id?api_key=$_apiKey&append_to_response=combined_credits');

    if (response != null && response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      
      final List<dynamic> creditsJson = data['combined_credits']?['cast'] ?? [];
      final List<Movie> credits = creditsJson
          .take(15)
          .map((item) => Movie.fromJson(item, isMovie: item['media_type'] == 'movie'))
          .toList();

      final actor = Actor.fromJson(data, credits);
      // Store credits in the cache map too
      final cacheData = actor.toJson();
      cacheData['credits'] = credits.map((m) => m.toJson()).toList();
      await CacheManager.save(cacheKey, cacheData, const Duration(days: 14));

      return actor;
    }
    return null;
  }

  Future<List<Movie>> getMoviesByGenre(
    String genreName, {
    bool isMovie = true,
    int page = 1,
    String? language,
    String? sortBy,
    String? monetization,
    bool forceRefresh = false,
  }) async {
    final genreId = _genreMap[genreName.toLowerCase()];
    if (genreId == null) return [];

    final cacheKey = 'movies_by_genre_${genreName}_${isMovie}_${page}_${language}_${sortBy}_${monetization}';
    if (!forceRefresh) {
      final cached = await CacheManager.get(cacheKey);
      if (cached != null) {
        return (cached as List).map((item) => Movie.fromJson(item, isMovie: isMovie)).toList();
      }
    }

    final type = isMovie ? 'movie' : 'tv';
    String url = '$_baseUrl/discover/$type?api_key=$_apiKey&with_genres=$genreId&page=$page';
    // ... (rest of URL building logic)
    
    if (language != null && language != 'all') {
      url += '&with_original_language=$language';
    }
    
    if (sortBy != null) {
      url += '&sort_by=$sortBy';
    } else {
      url += '&sort_by=popularity.desc';
    }

    if (monetization != null && monetization != 'all') {
      url += '&with_watch_monetization_types=$monetization&watch_region=US';
    }

    final response = await _safeGet(url);

    if (response != null && response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> results = data['results'];
      await CacheManager.save(cacheKey, results, const Duration(days: 1));
      return results.map((item) => Movie.fromJson(item, isMovie: isMovie)).toList();
    }
    return [];
  }



  Future<List<Movie>> getSimilarContent(String id, {bool isMovie = true, bool forceRefresh = false}) async {
    final cacheKey = 'similar_$id';
    if (!forceRefresh) {
      final cached = await CacheManager.get(cacheKey);
      if (cached != null) {
        return (cached as List).map((item) => Movie.fromJson(item, isMovie: isMovie)).toList();
      }
    }

    final type = isMovie ? 'movie' : 'tv';
    final response = await _safeGet('$_baseUrl/$type/$id/similar?api_key=$_apiKey');

    if (response != null && response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> results = data['results'] ?? [];
      await CacheManager.save(cacheKey, results, const Duration(days: 3));
      return results.map((item) => Movie.fromJson(item, isMovie: isMovie)).toList();
    }
    return [];
  }

  Future<List<Movie>> getRecommendations(String id, {bool isMovie = true, bool forceRefresh = false}) async {
    final cacheKey = 'recommendations_$id';
    if (!forceRefresh) {
      final cached = await CacheManager.get(cacheKey);
      if (cached != null) {
        return (cached as List).map((item) => Movie.fromJson(item, isMovie: isMovie)).toList();
      }
    }

    final type = isMovie ? 'movie' : 'tv';
    final response = await _safeGet('$_baseUrl/$type/$id/recommendations?api_key=$_apiKey');

    if (response != null && response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> results = data['results'] ?? [];
      await CacheManager.save(cacheKey, results, const Duration(days: 3));
      return results.map((item) => Movie.fromJson(item, isMovie: isMovie)).toList();
    }
    return [];
  }

  Future<List<Movie>> getTopRated({bool isMovie = true, bool forceRefresh = false}) async {
    final cacheKey = 'top_rated_$isMovie';
    if (!forceRefresh) {
      final cached = await CacheManager.get(cacheKey);
      if (cached != null) {
        return (cached as List).map((item) => Movie.fromJson(item, isMovie: isMovie)).toList();
      }
    }

    final type = isMovie ? 'movie' : 'tv';
    final response = await _safeGet('$_baseUrl/$type/top_rated?api_key=$_apiKey');

    if (response != null && response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> results = data['results'] ?? [];
      await CacheManager.save(cacheKey, results, const Duration(days: 1));
      return results.map((item) => Movie.fromJson(item, isMovie: isMovie)).toList();
    }
    return [];
  }

  Future<Season?> getSeasonDetails(String tvId, int seasonNumber, {bool forceRefresh = false}) async {
    final cacheKey = 'season_detail_${tvId}_$seasonNumber';
    if (!forceRefresh) {
      final cached = await CacheManager.get(cacheKey);
      if (cached != null) return Season.fromJson(cached);
    }

    final response = await _safeGet('$_baseUrl/tv/$tvId/season/$seasonNumber?api_key=$_apiKey');

    if (response != null && response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      await CacheManager.save(cacheKey, data, const Duration(days: 7));
      return Season.fromJson(data);
    }
    return null;
  }

  Future<List<Review>> getReviews(String id, {bool isMovie = true, bool forceRefresh = false}) async {
    final cacheKey = 'reviews_${id}_$isMovie';
    if (!forceRefresh) {
      final cached = await CacheManager.get(cacheKey);
      if (cached != null) {
        return (cached as List).map((item) => Review.fromJson(item)).toList();
      }
    }

    final type = isMovie ? 'movie' : 'tv';
    final response = await _safeGet('$_baseUrl/$type/$id/reviews?api_key=$_apiKey');

    if (response != null && response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> results = data['results'] ?? [];
      await CacheManager.save(cacheKey, results, const Duration(days: 1));
      return results.map((item) => Review.fromJson(item)).toList();
    }
    return [];
  }

  static const Map<String, int> _genreMap = {
    'action': 28,
    'adventure': 12,
    'animation': 16,
    'comedy': 35,
    'crime': 80,
    'documentary': 99,
    'drama': 18,
    'family': 10751,
    'fantasy': 14,
    'history': 36,
    'horror': 27,
    'music': 10402,
    'mystery': 9648,
    'romance': 10749,
    'science fiction': 878,
    'tv movie': 10770,
    'thriller': 53,
    'war': 10752,
    'western': 37,
  };

  Future<List<Movie>> getAnimeByStudio(int studioId, {int page = 1, bool forceRefresh = false}) async {
    final cacheKey = 'anime_studio_${studioId}_$page';
    if (!forceRefresh) {
      final cached = await CacheManager.get(cacheKey);
      if (cached != null) {
        return (cached as List).map((item) => Movie.fromJson(item, isMovie: false)).toList();
      }
    }

    final response = await _safeGet('$_baseUrl/discover/tv?api_key=$_apiKey&with_genres=16&with_companies=$studioId&page=$page');
    if (response != null && response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> results = data['results'];
      await CacheManager.save(cacheKey, results, const Duration(days: 1));
      final anime = results.map((item) => Movie.fromJson(item, isMovie: false)).toList();
      _precacheImages(anime);
      return anime;
    }
    return [];
  }
}
