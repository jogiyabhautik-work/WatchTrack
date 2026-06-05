import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:watch_track/features/soundtrack/domain/models/song_model.dart';
import 'package:watch_track/features/soundtrack/domain/enums/song_type.dart';
import 'package:watch_track/features/soundtrack/domain/enums/song_source.dart';

class YouTubeVideoData {
  final String id;
  final String title;
  final String type; // 'Trailer', 'Teaser', 'Song', etc.
  final String language; // 'English', 'Hindi', 'Japanese', etc.
  final bool isOfficial;

  YouTubeVideoData({
    required this.id,
    required this.title,
    required this.type,
    required this.language,
    this.isOfficial = false,
  });
}

class GlobalYouTubeService {
  static final GlobalYouTubeService _instance =
      GlobalYouTubeService._internal();
  factory GlobalYouTubeService() => _instance;
  GlobalYouTubeService._internal();

  final YoutubeExplode _yt = YoutubeExplode();
  static final String _tmdbApiKey = dotenv.get('TMDB_API_KEY', fallback: '');
  static const String _tmdbBaseUrl = 'https://api.themoviedb.org/3';

  Future<http.Response?> _safeGet(String url) async {
    try {
      String finalUrl = url;
      if (kIsWeb) {
        finalUrl = 'https://corsproxy.io/?${Uri.encodeComponent(url)}';
      }
      return await http.get(Uri.parse(finalUrl));
    } catch (e) {
      debugPrint('GlobalYouTubeService TMDB Error: $e');
      return null;
    }
  }

  /// Maps iso_639_1 to Language Names
  String _getLanguageName(String isoCode, String title) {
    title = title.toLowerCase();
    if (title.contains('hindi')) return 'Hindi';
    if (title.contains('tamil')) return 'Tamil';
    if (title.contains('telugu')) return 'Telugu';
    if (title.contains('japanese') || title.contains('sub') || isoCode == 'ja') {
      return 'Japanese';
    }
    if (title.contains('korean') || isoCode == 'ko') return 'Korean';
    if (title.contains('dubbed') || title.contains('dub')) return 'Dubbed';

    switch (isoCode) {
      case 'hi':
        return 'Hindi';
      case 'ta':
        return 'Tamil';
      case 'te':
        return 'Telugu';
      case 'en':
        return 'English';
      case 'ja':
        return 'Japanese';
      case 'ko':
        return 'Korean';
      case 'es':
        return 'Spanish';
      case 'fr':
        return 'French';
      default:
        return isoCode.toUpperCase();
    }
  }

  /// Fetches trailers and teasers for a media item.
  /// Fetches trailers and teasers for a media item.
  Future<List<YouTubeVideoData>> getTrailers({
    required String tmdbId,
    required bool isMovie,
    required String title,
    String? year,
    String? languagePreference,
  }) async {
    final type = isMovie ? 'movie' : 'tv';
    final response = await _safeGet(
      '$_tmdbBaseUrl/$type/$tmdbId/videos?api_key=$_tmdbApiKey',
    );

    List<YouTubeVideoData> videos = [];

    if (response != null && response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> results = data['results'] ?? [];

      for (var v in results) {
        if (v['site'] == 'YouTube' &&
            (v['type'] == 'Trailer' || v['type'] == 'Teaser')) {
          videos.add(
            YouTubeVideoData(
              id: v['key'],
              title: v['name'] ?? '${v['type']}',
              type: v['type'],
              language: _getLanguageName(
                v['iso_639_1'] ?? 'en',
                v['name'] ?? '',
              ),
              isOfficial: v['official'] ?? false,
            ),
          );
        }
      }
    }

    // Sort by Official first, then language preference
    videos.sort((a, b) {
      if (languagePreference != null) {
        if (a.language.toLowerCase() == languagePreference.toLowerCase() &&
            b.language.toLowerCase() != languagePreference.toLowerCase()) {
          return -1;
        }
        if (b.language.toLowerCase() == languagePreference.toLowerCase() &&
            a.language.toLowerCase() != languagePreference.toLowerCase()) {
          return 1;
        }
      }
      if (a.isOfficial && !b.isOfficial) return -1;
      if (b.isOfficial && !a.isOfficial) return 1;
      return 0;
    });

    // Fallback to YouTube search if TMDB has no trailers
    if (videos.isEmpty) {
      try {
        final normalized = await getNormalizedMedia(
          contentType: isMovie ? 'movie' : 'tv',
          title: title,
          releaseYear: year,
          language: languagePreference,
          mediaType: 'trailer',
        );
        for (var v in normalized) {
          videos.add(
            YouTubeVideoData(
              id: v.id,
              title: v.title,
              type: 'Trailer',
              language: languagePreference ?? 'English',
              isOfficial: v.isOfficial,
            ),
          );
        }
      } catch (e) {
        debugPrint('YouTube trailer fallback failed: $e');
      }
    }

    return videos;
  }

  /// High-fidelity global query and matching engine
  Future<List<SongModel>> getNormalizedMedia({
    required String contentType, // movie / series / anime
    required String title,
    String? originalTitle,
    String? releaseYear,
    String? tmdbId,
    String? seasonNumber,
    String? episodeNumber,
    String? language,
    required String
    mediaType, // trailer / teaser / soundtrack / ost / song / video
    String? songTitle,
    String? artistName,
    String? youtubeVideoId,
    String? thumbnail,
    String? duration,
    String? sourceChannel,
  }) async {
    // 1. Direct Video ID lookup
    if (youtubeVideoId != null && youtubeVideoId.isNotEmpty) {
      try {
        final video = await _yt.videos.get(youtubeVideoId);
        return [
          SongModel.create(
            id: video.id.value,
            title: video.title,
            artist: video.author,
            type: _mapMediaTypeToSongType(mediaType),
            source: SongSource.youtube,
            externalUrl: video.url,
            thumbnailUrl: video.thumbnails.highResUrl,
            duration: video.duration?.toString().split('.').first ?? '',
            subtitle: video.author,
            contentTitle: title,
            contentType: contentType,
            mediaType: mediaType,
            language: language ?? 'English',
            channelName: video.author,
            isOfficial: _checkIsOfficial(video.author, video.title),
            isLikelyAccurate: true,
            confidenceScore: 1.0,
            reason: 'Direct ID lookup.',
            availableModes: const ['audio', 'video'],
          ),
        ];
      } catch (e) {
        debugPrint('Error loading direct YouTube ID: $e');
      }
    }

    // 2. Build precision search query
    String query = '';
    if (mediaType == 'trailer' || mediaType == 'teaser') {
      String suffix = mediaType == 'trailer'
          ? 'official trailer'
          : 'official teaser';
      if (seasonNumber != null && seasonNumber.isNotEmpty) {
        query = '$title season $seasonNumber $suffix';
      } else {
        query = '$title ${releaseYear ?? ''} $suffix';
      }
      if (language != null && language.isNotEmpty) {
        query += ' $language';
      }
    } else {
      // soundtrack, ost, song, video
      if (songTitle != null && songTitle.isNotEmpty) {
        query = '$title $songTitle';
        if (artistName != null && artistName.isNotEmpty) {
          query += ' $artistName';
        }
        query += ' official audio';
      } else {
        if (contentType == 'anime') {
          query = '$title opening ending ost';
        } else if (contentType == 'movie') {
          query = '$title ${releaseYear ?? ''} soundtrack official audio';
        } else {
          query = '$title tv series ost official audio';
        }
      }
    }

    try {
      final searchResults = await _yt.search.search(query);
      if (searchResults.isEmpty) return [];

      List<SongModel> songs = [];

      for (var video in searchResults) {
        final durationVal = video.duration;
        if (durationVal == null) continue;

        final t = video.title.toLowerCase();
        final ch = video.author.toLowerCase();

        // STRICT FILTERS
        // Reject reviews, reactions, fan made, mashups, behind the scenes, compilations
        if (t.contains('reaction') ||
            t.contains('review') ||
            t.contains('fanmade') ||
            t.contains('fan made') ||
            t.contains('mashup') ||
            t.contains('behind the scenes') ||
            t.contains('interview') ||
            t.contains('concept') ||
            t.contains('full album') ||
            t.contains('compilation') ||
            t.contains('playlist') ||
            t.contains('mash-up') ||
            t.contains('fake') ||
            t.contains('parody') ||
            t.contains('loop') ||
            t.contains('1 hour') ||
            t.contains('1hour')) {
          continue;
        }

        // Reject fake soundtracks/songs if they are extremely long (e.g. > 10 min for a single song)
        if ((mediaType == 'soundtrack' ||
                mediaType == 'ost' ||
                mediaType == 'song') &&
            durationVal.inMinutes > 10) {
          continue;
        }

        // Reject trailer results in soundtrack section, and vice versa
        if ((mediaType == 'soundtrack' ||
                mediaType == 'ost' ||
                mediaType == 'song') &&
            t.contains('trailer')) {
          continue;
        }
        if ((mediaType == 'trailer' || mediaType == 'teaser') &&
            (t.contains('soundtrack') ||
                t.contains('ost') ||
                t.contains('full ost'))) {
          continue;
        }

        // CALCULATE SCORING
        double score = 1.0;
        List<String> reasons = [];

        // 1. Exact content title match
        final normalizedTitle = title.toLowerCase();
        if (t.contains(normalizedTitle)) {
          score += 0.3;
          reasons.add('Content title matched');
        } else {
          final words = normalizedTitle
              .split(' ')
              .where((w) => w.length > 2)
              .toList();
          int wordMatches = 0;
          for (var w in words) {
            if (t.contains(w)) wordMatches++;
          }
          if (wordMatches > 0) {
            score += 0.1 * wordMatches;
          } else {
            score -= 0.4;
          }
        }

        // 2. Song title match if soundtrack
        if (songTitle != null && songTitle.isNotEmpty) {
          if (t.contains(songTitle.toLowerCase())) {
            score += 0.4;
            reasons.add('Song title matched');
          } else {
            score -= 0.3;
          }
        }

        // 3. Official/Verified Channel
        bool isOfficial = _checkIsOfficial(video.author, video.title);
        if (isOfficial) {
          score += 0.3;
          reasons.add('Official/Verified channel');
        }

        // 4. Correct Year
        if (releaseYear != null && releaseYear.isNotEmpty) {
          if (t.contains(releaseYear)) {
            score += 0.2;
            reasons.add('Release year matched');
          }
        }

        // 5. Reasonable Duration
        if (mediaType == 'trailer' || mediaType == 'teaser') {
          if (durationVal.inMinutes <= 4) {
            score += 0.1;
          } else {
            score -= 0.3;
          }
        } else {
          if (durationVal.inMinutes >= 2 && durationVal.inMinutes <= 7) {
            score += 0.1;
          } else {
            score -= 0.3;
          }
        }

        // 6. Language Match
        if (language != null && language.isNotEmpty) {
          if (t.contains(language.toLowerCase())) {
            score += 0.2;
            reasons.add('Language matched');
          }
        }

        bool isLikelyAccurate = score >= 1.0;
        String reason = reasons.isEmpty
            ? 'General search result.'
            : '${reasons.join(', ')}.';
        if (!isLikelyAccurate) {
          reason = 'Low confidence match. $reason';
        }

        songs.add(
          SongModel.create(
            id: video.id.value,
            title: video.title,
            artist: video.author,
            type: _mapMediaTypeToSongType(mediaType),
            source: SongSource.youtube,
            externalUrl: video.url,
            thumbnailUrl: video.thumbnails.highResUrl,
            duration: video.duration?.toString().split('.').first ?? '',
            subtitle: video.author,
            contentTitle: title,
            contentType: contentType,
            mediaType: mediaType,
            language: language ?? 'English',
            channelName: video.author,
            isOfficial: isOfficial,
            isLikelyAccurate: isLikelyAccurate,
            confidenceScore: score,
            reason: reason,
            availableModes: const ['audio', 'video'],
          ),
        );
      }

      // Sort by confidence score
      songs.sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));

      // Deduplicate
      final seenIds = <String>{};
      final uniqueSongs = <SongModel>[];
      for (var s in songs) {
        if (seenIds.add(s.id)) {
          uniqueSongs.add(s);
        }
      }

      return uniqueSongs;
    } catch (e) {
      debugPrint('Exception in GlobalYouTubeService.getNormalizedMedia: $e');
      return [];
    }
  }

  SongType _mapMediaTypeToSongType(String mediaType) {
    if (mediaType == 'opening') return SongType.opening;
    if (mediaType == 'ending') return SongType.ending;
    return SongType.soundtrack;
  }

  bool _checkIsOfficial(String author, String title) {
    final ch = author.toLowerCase();
    final t = title.toLowerCase();
    return ch.contains('official') ||
        ch.contains('vevo') ||
        ch.contains('records') ||
        ch.contains('music') ||
        ch.contains('t-series') ||
        ch.contains('tseries') ||
        ch.contains('netflix') ||
        ch.contains('sony') ||
        ch.contains('warner') ||
        ch.contains('universal') ||
        ch.contains('marvel') ||
        ch.contains('hbo') ||
        ch.contains('paramount') ||
        ch.contains('disney') ||
        ch.contains('pixar') ||
        ch.contains('crunchyroll') ||
        ch.contains('aniplex') ||
        ch.contains('lala') ||
        ch.contains('toho') ||
        ch.contains('dvd') ||
        t.contains('official') ||
        t.contains('teaser') ||
        t.contains('trailer') ||
        t.contains('ost');
  }

  /// Fetches soundtracks/OSTs using accurate rules.
  Future<List<SongModel>> getSoundtracks({
    required String title,
    required bool isMovie,
    required bool isAnime,
    String? year,
  }) async {
    return getNormalizedMedia(
      contentType: isAnime ? 'anime' : (isMovie ? 'movie' : 'series'),
      title: title,
      releaseYear: year,
      mediaType: 'soundtrack',
    );
  }

  /// Extracts the direct audio stream URL for a given YouTube Video ID
  Future<String?> getAudioStreamUrl(
    String videoId, {
    String? fallbackQuery,
  }) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);

      // ALWASYS use Muxed streams (video+audio) because audioOnly streams are heavily throttled/blocked by YouTube (returning 403)
      final muxedStreams = manifest.muxed.toList();
      if (muxedStreams.isNotEmpty) {
        // Use the lowest quality video stream to save bandwidth, since we only need audio
        return muxedStreams.last.url.toString();
      }

      // Absolute fallback if no muxed stream exists
      return manifest.audioOnly.first.url.toString();
    } catch (e) {
      debugPrint('Exception extracting audio stream via YouTube Explode: $e');

      debugPrint('Attempting Private Proxy fallback for video $videoId...');
      final proxyUrl = await _getFallbackAudioStream(videoId);
      if (proxyUrl != null) {
        return proxyUrl;
      }
      
      if (fallbackQuery != null && fallbackQuery.trim().isNotEmpty) {
        debugPrint('Attempting JioSaavn fallback for query: $fallbackQuery...');
        return await _getJioSaavnAudioStream(fallbackQuery.trim());
      }
      
      return null;
    }
  }

  /// Fallback resolver that queries the custom private backend to bypass YouTube rate limits
  Future<String?> _getFallbackAudioStream(String videoId) async {
    const proxyUrl = 'https://lyrics.lewdhutao.my.eu.org/v2/youtube/stream';

    try {
      final uri = Uri.parse('$proxyUrl?id=$videoId');
      debugPrint('Trying Private Proxy: $uri');

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final streamUrl = data['url'] as String?;

        if (streamUrl != null && streamUrl.isNotEmpty) {
          debugPrint('Successfully extracted stream from Private Proxy.');
          return streamUrl;
        }
      } else {
        debugPrint(
          'Private Proxy returned status ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Private Proxy failed: $e');
    }

    debugPrint('Fallback proxy failed to extract audio stream for $videoId');
    return null;
  }

  /// Fallback resolver that queries JioSaavn to get full MP4 track
  Future<String?> _getJioSaavnAudioStream(String query) async {
    try {
      // 1. Search JioSaavn
      final searchUri = Uri.parse(
        'https://www.jiosaavn.com/api.php?__call=autocomplete.get&query=${Uri.encodeComponent(query)}&_format=json&_marker=0&ctx=web6dot0',
      );
      final searchResponse = await http
          .get(searchUri)
          .timeout(const Duration(seconds: 5));

      if (searchResponse.statusCode != 200) return null;
      final searchData = jsonDecode(searchResponse.body);
      final songsData = searchData['songs']?['data'] as List<dynamic>?;
      if (songsData == null || songsData.isEmpty) return null;

      final songId = songsData[0]['id'] as String?;
      if (songId == null) return null;

      // 2. Get Details to extract encrypted_media_url
      final detailsUri = Uri.parse(
        'https://www.jiosaavn.com/api.php?__call=song.getDetails&cc=in&_marker=0%3F_marker%3D0&_format=json&pids=$songId',
      );
      final detailsResponse = await http
          .get(detailsUri)
          .timeout(const Duration(seconds: 5));
      if (detailsResponse.statusCode != 200) return null;

      final detailsData = jsonDecode(detailsResponse.body);
      final songDetails = detailsData[songId] as Map<String, dynamic>?;
      if (songDetails == null) return null;

      final encryptedUrl = songDetails['encrypted_media_url'] as String?;
      if (encryptedUrl == null || encryptedUrl.isEmpty) return null;

      // 3. Generate Auth Token to decrypt full stream
      final encodedEncryptedUrl = Uri.encodeComponent(encryptedUrl);
      final authUri = Uri.parse(
        'https://www.jiosaavn.com/api.php?__call=song.generateAuthToken&url=$encodedEncryptedUrl&bitrate=320&api_version=4&_format=json&ctx=web6dot0&_marker=0',
      );
      final authResponse = await http
          .get(authUri)
          .timeout(const Duration(seconds: 5));

      if (authResponse.statusCode != 200) return null;
      final authData = jsonDecode(authResponse.body);

      final streamUrl = authData['auth_url'] as String?;
      if (streamUrl != null && streamUrl.isNotEmpty) {
        debugPrint(
          'Successfully extracted full stream from JioSaavn for: $query',
        );
        return streamUrl;
      }
    } catch (e) {
      debugPrint('Exception in JioSaavn fallback: $e');
    }
    return null;
  }

  /// General search for any song (used by Audio Library search)
  Future<List<SongModel>> searchSongs(String query) async {
    try {
      final searchResults = await _yt.search.search(query);
      if (searchResults.isEmpty) return [];

      List<SongModel> songs = [];
      for (var video in searchResults) {
        if (video.duration == null || video.duration!.inMinutes > 20) {
          continue; // Skip very long videos
        }

        songs.add(
          SongModel.create(
            id: video.id.value,
            title: video.title,
            artist: video.author,
            type: SongType.soundtrack,
            source: SongSource.youtube,
            externalUrl: video.url,
            thumbnailUrl: video.thumbnails.highResUrl,
            duration: video.duration?.toString().split('.').first ?? '',
            subtitle: video.author,
            contentTitle: 'Search Result',
            contentType: 'music',
            mediaType: 'song',
            language: 'Unknown',
            channelName: video.author,
            isOfficial: _checkIsOfficial(video.author, video.title),
            isLikelyAccurate: true,
            confidenceScore: 1.0,
            reason: 'User Search',
            availableModes: const ['audio', 'video'],
          ),
        );
      }
      return songs;
    } catch (e) {
      debugPrint('Exception in GlobalYouTubeService.searchSongs: $e');
      return [];
    }
  }

  void dispose() {
    _yt.close();
  }
}
