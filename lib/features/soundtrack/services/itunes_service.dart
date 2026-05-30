import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:watch_track/features/soundtrack/domain/models/song_model.dart';
import 'package:watch_track/features/soundtrack/domain/enums/song_type.dart';
import 'package:watch_track/features/soundtrack/domain/enums/song_source.dart';

class ITunesService {
  static const String _baseUrl = 'https://itunes.apple.com';

  Future<List<SongModel>> getSoundtrackForMedia(String title, bool isMovie) async {
    try {
      // Search iTunes for the title + 'soundtrack'
      final query = Uri.encodeComponent('$title soundtrack');
      final url = Uri.parse('$_baseUrl/search?term=$query&media=music&entity=song&limit=15');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = await compute(jsonDecode, response.body) as Map<String, dynamic>;
        final results = data['results'] as List?;

        if (results == null || results.isEmpty) {
          return [];
        }

        List<SongModel> songs = [];

        for (var track in results) {
          songs.add(
            SongModel.create(
              id: track['trackId']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
              title: track['trackName']?.toString() ?? 'Unknown Title',
              artist: track['artistName']?.toString() ?? 'Unknown Artist',
              type: SongType.soundtrack,
              source: SongSource.itunes,
              externalUrl: track['previewUrl']?.toString() ?? track['trackViewUrl']?.toString(),
            ),
          );
        }

        return songs;
      } else {
        debugPrint('iTunes API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Exception in ITunesService: $e');
      return [];
    }
  }
}
