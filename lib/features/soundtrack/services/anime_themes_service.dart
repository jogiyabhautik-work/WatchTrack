import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:watch_track/features/soundtrack/domain/models/song_model.dart';
import 'package:watch_track/features/soundtrack/domain/enums/song_type.dart';
import 'package:watch_track/features/soundtrack/domain/enums/song_source.dart';

class AnimeThemesService {
  static const String _baseUrl = 'https://api.animethemes.moe';

  Future<List<SongModel>> getThemesForAnime(String title) async {
    try {
      // We search for the anime by title and include the themes, songs, and video links
      final query = Uri.encodeQueryComponent(title);
      final url = Uri.parse(
          '$_baseUrl/anime?q=$query&include=animethemes.animethemeentries.videos,animethemes.song');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = await compute(jsonDecode, response.body) as Map<String, dynamic>;
        final searchResults = data['anime'] as List?;

        if (searchResults == null || searchResults.isEmpty) {
          return [];
        }

        // We try to find an exact match first, otherwise fallback to the first result
        var bestMatch = searchResults.first;
        for (var anime in searchResults) {
          final name = anime['name']?.toString().toLowerCase() ?? '';
          if (name == title.toLowerCase()) {
            bestMatch = anime;
            break;
          }
        }
        
        final themes = bestMatch['animethemes'] as List?;

        if (themes == null || themes.isEmpty) {
          return [];
        }

        List<SongModel> songs = [];

        for (var theme in themes) {
          final typeStr = theme['type']?.toString().toUpperCase() ?? '';
          SongType type = SongType.unknown;
          if (typeStr == 'OP') type = SongType.opening;
          else if (typeStr == 'ED') type = SongType.ending;
          else if (typeStr == 'IN') type = SongType.insert;

          final songData = theme['song'];
          final songTitle = songData?['title']?.toString() ?? 'Unknown Title';
          
          // AnimeThemes doesn't prominently expose artist in this simplified query, 
          // but we can try to extract if available, else default.
          final artist = 'Original Soundtrack'; // AnimeThemes usually links artists separately

          final entries = theme['animethemeentries'] as List?;
          String? episodes;
          String? videoLink;

          if (entries != null && entries.isNotEmpty) {
            final firstEntry = entries.first;
            episodes = firstEntry['episodes']?.toString();
            
            final videos = firstEntry['videos'] as List?;
            if (videos != null && videos.isNotEmpty) {
              videoLink = videos.first['link']?.toString();
            }
          }

          songs.add(
            SongModel.create(
              id: theme['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
              title: songTitle,
              artist: artist,
              type: type,
              episode: episodes,
              source: SongSource.animeThemes,
              externalUrl: videoLink,
            ),
          );
        }

        return songs;
      } else {
        debugPrint('AnimeThemes API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Exception in AnimeThemesService: $e');
      return [];
    }
  }
}
