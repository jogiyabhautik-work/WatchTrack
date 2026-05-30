import 'package:flutter/foundation.dart';
import 'package:watch_track/features/soundtrack/domain/models/song_model.dart';
import 'package:watch_track/features/soundtrack/services/anime_themes_service.dart';
import 'package:watch_track/features/soundtrack/services/youtube_service.dart';

class SoundtrackRepository {
  final AnimeThemesService _animeThemesService;
  final YouTubeService _youtubeService;

  // Simple in-memory cache mapping mediaId to list of songs
  final Map<String, List<SongModel>> _cache = {};

  // Singleton pattern for simple caching across the app
  static final SoundtrackRepository _instance = SoundtrackRepository._internal();
  factory SoundtrackRepository() => _instance;

  SoundtrackRepository._internal({
    AnimeThemesService? animeThemesService,
    YouTubeService? youtubeService,
  })  : _animeThemesService = animeThemesService ?? AnimeThemesService(),
        _youtubeService = youtubeService ?? YouTubeService();

  Future<List<SongModel>> getSongs({
    required String mediaId,
    required String title,
    required bool isAnime,
    required bool isMovie,
  }) async {
    // 1. Check local cache
    if (_cache.containsKey(mediaId)) {
      debugPrint('Returning soundtrack from cache for $title');
      return _cache[mediaId]!;
    }

    List<SongModel> songs = [];

    // 2. Fetch based on media type
    if (isAnime) {
      debugPrint('Fetching AnimeThemes for $title');
      songs = await _animeThemesService.getThemesForAnime(title);
    } else {
      debugPrint('Fetching YouTube for $title');
      songs = await _youtubeService.getSoundtrackForMedia(title, isMovie);
    }

    // 3. Cache results (even if empty, to prevent repeated failing requests)
    _cache[mediaId] = songs;

    return songs;
  }

  void clearCache() {
    _cache.clear();
  }
}
