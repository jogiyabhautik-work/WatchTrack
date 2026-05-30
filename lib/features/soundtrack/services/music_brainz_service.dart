import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:watch_track/features/soundtrack/domain/models/song_model.dart';
import 'package:watch_track/features/soundtrack/domain/enums/song_type.dart';
import 'package:watch_track/features/soundtrack/domain/enums/song_source.dart';

class MusicBrainzService {
  static const String _baseUrl = 'https://musicbrainz.org/ws/2';
  static const String _userAgent = 'WatchTrack/1.0 ( watchtrack@example.com )';

  // Strict 1 request per second rate limiting for MusicBrainz
  static DateTime? _lastRequestTime;
  static final _lock = _Mutex();

  Future<void> _enforceRateLimit() async {
    await _lock.acquire();
    try {
      if (_lastRequestTime != null) {
        final timeSinceLast = DateTime.now().difference(_lastRequestTime!);
        if (timeSinceLast.inMilliseconds < 1100) { // 1.1 sec to be safe
          await Future.delayed(Duration(milliseconds: 1100 - timeSinceLast.inMilliseconds));
        }
      }
      _lastRequestTime = DateTime.now();
    } finally {
      _lock.release();
    }
  }

  Future<List<SongModel>> getSoundtrackForMedia(String title, bool isMovie) async {
    try {
      // Search for release groups matching the title and type:soundtrack
      final query = Uri.encodeComponent('"$title" AND type:soundtrack');
      final searchUrl = Uri.parse('$_baseUrl/release-group?query=$query&fmt=json&limit=1');

      await _enforceRateLimit();
      final searchRes = await http.get(searchUrl, headers: {'User-Agent': _userAgent});

      if (searchRes.statusCode != 200) {
        debugPrint('MusicBrainz Search error: ${searchRes.statusCode}');
        return [];
      }

      final searchData = jsonDecode(searchRes.body);
      final releaseGroups = searchData['release-groups'] as List?;

      if (releaseGroups == null || releaseGroups.isEmpty) {
        return [];
      }

      final bestMatchId = releaseGroups.first['id']?.toString();
      if (bestMatchId == null) return [];

      // Fetch the releases for this release group to get track data
      final releaseUrl = Uri.parse('$_baseUrl/release-group/$bestMatchId?inc=releases+recordings+artist-credits&fmt=json');
      
      await _enforceRateLimit();
      final releaseRes = await http.get(releaseUrl, headers: {'User-Agent': _userAgent});

      if (releaseRes.statusCode != 200) {
        return [];
      }

      final releaseData = jsonDecode(releaseRes.body);
      final releases = releaseData['releases'] as List?;
      
      if (releases == null || releases.isEmpty) return [];

      final firstRelease = releases.first;
      final media = firstRelease['media'] as List?;
      if (media == null || media.isEmpty) return [];

      final tracks = media.first['tracks'] as List?;
      if (tracks == null || tracks.isEmpty) return [];

      List<SongModel> songs = [];

      for (var track in tracks) {
        final trackId = track['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
        final songTitle = track['title']?.toString() ?? 'Unknown Title';
        
        // Extract artist
        String artistName = 'Various Artists';
        final artistCredits = track['artist-credit'] as List?;
        if (artistCredits != null && artistCredits.isNotEmpty) {
          artistName = artistCredits.map((ac) => ac['name']?.toString() ?? '').join(', ');
        }

        songs.add(SongModel.create(
          id: trackId,
          title: songTitle,
          artist: artistName,
          type: SongType.soundtrack,
          source: SongSource.musicBrainz,
        ));
      }

      return songs;

    } catch (e) {
      debugPrint('Exception in MusicBrainzService: $e');
      return [];
    }
  }
}

// Simple Mutex for rate limiting queue
class _Mutex {
  Completer<void>? _completer;

  Future<void> acquire() async {
    while (_completer != null) {
      await _completer!.future;
    }
    _completer = Completer<void>();
  }

  void release() {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete();
      _completer = null;
    }
  }
}
