// lib/core/services/lyrics_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../providers/synced_lyrics_model.dart';

@immutable
class LyricsSearchAttempt {
  final String artist;
  final String title;
  final String reason;

  const LyricsSearchAttempt({
    required this.artist,
    required this.title,
    required this.reason,
  });

  String get key => '${artist.toLowerCase()}::${title.toLowerCase()}';

  @override
  String toString() => '$artist - $title ($reason)';
}

class LyricsService {
  static const int _maxLookupAttempts = 16;

  static const List<String> _knownSingers = [
    'Arijit Singh',
    'Shreya Ghoshal',
    'Atif Aslam',
    'Armaan Malik',
    'Amaal Mallik',
    'Amit Trivedi',
    'Pritam',
    'Vishal Dadlani',
    'Shekhar Ravjiani',
    'Neha Kakkar',
    'Jubin Nautiyal',
    'Sonu Nigam',
    'Mohit Chauhan',
    'KK',
    'Asha Bhosle',
    'Kishore Kumar',
    'Lata Mangeshkar',
    'Sunidhi Chauhan',
    'A R Rahman',
    'A. R. Rahman',
    'Shilpa Rao',
    'Sachet Tandon',
    'Parampara Tandon',
    'Darshan Raval',
    'Rahat Fateh Ali Khan',
    'Diljit Dosanjh',
    'Sid Sriram',
    'Anirudh Ravichander',
    'Shankar Mahadevan',
    'Taylor Swift',
    'Ariana Grande',
    'Billie Eilish',
    'Ed Sheeran',
    'The Weeknd',
    'Adele',
    'Coldplay',
    'Imagine Dragons',
    'Linkin Park',
  ];

  static const List<String> _fallbackArtists = [
    'Arijit Singh',
    'Shreya Ghoshal',
    'Atif Aslam',
    'Jubin Nautiyal',
    'Sonu Nigam',
    'KK',
    'Taylor Swift',
    'Ed Sheeran',
  ];

  static final RegExp _noiseWords = RegExp(
    r'\b(official|video|lyric|lyrics|audio|full|song|hd|4k|8k|ost|soundtrack|'
    r'jukebox|trailer|teaser|promo|clip|scene|remastered|remaster|status|'
    r'whatsapp|movie|film|cinema|theme|title track|motion poster)\b',
    caseSensitive: false,
  );

  static final RegExp _genericArtistWords = RegExp(
    r'\b(unknown artist|youtube video|vevo|records|record label|official|topic|'
    r'channel|studio|studios|entertainment|songs|music|t-series|tseries|'
    r'zee music|sony music|saregama|tips|yash raj|yrf|eros now|aditya music|'
    r'lahari music|think music|times music|netflix|disney|warner|universal)\b',
    caseSensitive: false,
  );

  /// Fetches synced lyrics first and falls back to plain lyrics.
  ///
  /// YouTube titles often contain movie names, cast names, labels, and quality
  /// tags. Build several clean artist/title attempts before asking lyric APIs.
  static Future<SyncedLyrics?> fetchSyncedLyrics(
    String artist,
    String title, {
    Duration? duration,
  }) async {
    final attempts = buildLookupAttempts(artist, title);
    if (attempts.isEmpty) return null;

    final topAttempts = attempts.take(3).toList();

    debugPrint(
      'Lyrics lookup concurrent attempts: ${topAttempts.map((a) => '${a.artist} / ${a.title}').join(' | ')}',
    );

    final futures = <Future<SyncedLyrics?>>[];

    for (final attempt in topAttempts) {
      futures.add(
        _fetchFromLrcLib(attempt.artist, attempt.title, duration: duration),
      );
      futures.add(
        _fetchFromLewdHuTao(attempt.artist, attempt.title, 'musixmatch'),
      );
      futures.add(
        _fetchFromLewdHuTao(attempt.artist, attempt.title, 'youtube'),
      );
      futures.add(_fetchFromGeniusScraper(attempt.artist, attempt.title));
      futures.add(_fetchPlainLyrics(attempt.artist, attempt.title));
    }

    final result = await _raceForLyrics(futures);
    if (result != null) return result;

    debugPrint(
      'Lyrics not found after concurrent requests for "$artist" / "$title"',
    );
    return null;
  }

  static Future<SyncedLyrics?> _raceForLyrics(
    List<Future<SyncedLyrics?>> futures,
  ) {
    final completer = Completer<SyncedLyrics?>();
    int pending = futures.length;
    SyncedLyrics? bestPlainFallback;

    for (final future in futures) {
      future
          .then((result) {
            if (result != null) {
              if (result.isSynced) {
                if (!completer.isCompleted) {
                  completer.complete(result);
                }
              } else {
                bestPlainFallback ??= result;
              }
            }
            pending--;
            if (pending == 0 && !completer.isCompleted) {
              completer.complete(bestPlainFallback);
            }
          })
          .catchError((_) {
            pending--;
            if (pending == 0 && !completer.isCompleted) {
              completer.complete(bestPlainFallback);
            }
          });
    }

    if (futures.isEmpty) {
      completer.complete(null);
    }

    return completer.future;
  }

  static Future<SyncedLyrics?> _fetchFromLewdHuTao(
    String artist,
    String title,
    String source,
  ) async {
    try {
      final uri = Uri.https(
        'lyrics.lewdhutao.my.eu.org',
        '/v2/$source/lyrics',
        {'title': title, 'artist': artist},
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final innerData = data['data'];
        if (innerData != null && innerData is Map<String, dynamic>) {
          final lyrics = innerData['lyrics'] as String?;
          if (lyrics != null && lyrics.trim().isNotEmpty) {
            if (lyrics.contains(RegExp(r'\[\d{2}:\d{2}\.\d{2,3}\]'))) {
              debugPrint(
                'Found synced lyrics from LewdHuTao ($source): $artist / $title',
              );
              return SyncedLyrics.fromLrc(lyrics);
            }
            debugPrint(
              'Found plain lyrics from LewdHuTao ($source): $artist / $title',
            );
            return SyncedLyrics.fromPlainText(_formatLyrics(lyrics));
          }
        }
      }
    } catch (e) {
      debugPrint('LewdHuTao ($source) error for "$artist" / "$title": $e');
    }
    return null;
  }

  static Future<SyncedLyrics?> _fetchFromGeniusScraper(
    String artist,
    String title,
  ) async {
    try {
      final path =
          '${artist.replaceAll(' ', '-')}-${title.replaceAll(' ', '-')}-lyrics'
              .replaceAll(RegExp(r'[^a-zA-Z0-9\-]'), '');

      final uri = Uri.parse('https://genius.com/$path');
      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final html = response.body;
        final match = RegExp(
          r'<div data-lyrics-container="true"[^>]*>(.*?)</div>',
          dotAll: true,
        ).firstMatch(html);
        if (match != null) {
          var lyricsHtml = match.group(1) ?? '';
          lyricsHtml = lyricsHtml.replaceAll(RegExp(r'<br\s*/?>'), '\n');
          lyricsHtml = lyricsHtml.replaceAll(RegExp(r'<[^>]*>'), '');

          if (lyricsHtml.trim().isNotEmpty) {
            debugPrint(
              'Found plain lyrics from Genius Scraper: $artist / $title',
            );
            return SyncedLyrics.fromPlainText(_formatLyrics(lyricsHtml));
          }
        }
      }
    } catch (e) {
      debugPrint('Genius Scraper error for "$artist" / "$title": $e');
    }
    return null;
  }

  /// Exposed for tests and debugging previews.
  static List<LyricsSearchAttempt> buildLookupAttempts(
    String artist,
    String title,
  ) {
    final titles = _expandTitleVariations(_extractTitleCandidates(title));
    if (titles.isEmpty) return const [];

    final extractedArtists = _extractArtistsFromTitle(title);
    final cleanedInputArtist = _cleanArtist(artist);
    final artists = <String>[];

    artists.addAll(extractedArtists);
    if (cleanedInputArtist.isNotEmpty &&
        !_isGenericArtist(cleanedInputArtist)) {
      artists.add(cleanedInputArtist);
    }

    if (artists.isEmpty) {
      artists.addAll(_fallbackArtists);
    }

    final artistVariations = _expandArtistVariations(artists);
    final attempts = <LyricsSearchAttempt>[];
    final seen = <String>{};

    void addAttempt(String artist, String title, String reason) {
      final normalizedArtist = _cleanArtist(artist);
      final normalizedTitle = _cleanTitleForApi(title);
      if (normalizedArtist.isEmpty || normalizedTitle.isEmpty) return;

      final attempt = LyricsSearchAttempt(
        artist: normalizedArtist,
        title: normalizedTitle,
        reason: reason,
      );
      if (seen.add(attempt.key)) {
        attempts.add(attempt);
      }
    }

    for (final artist in artistVariations) {
      for (final title in titles) {
        addAttempt(artist, title, 'cleaned metadata');
        if (attempts.length >= _maxLookupAttempts) return attempts;
      }
    }

    return attempts;
  }

  /// Legacy method: returns raw plain text lyrics.
  static Future<String?> fetchLyrics(String artist, String title) async {
    final result = await fetchSyncedLyrics(artist, title);
    if (result == null) return null;
    return result.lines.map((line) => line.text).join('\n');
  }

  static Future<SyncedLyrics?> _fetchFromLrcLib(
    String artist,
    String title, {
    Duration? duration,
  }) async {
    try {
      final params = {
        'artist_name': artist,
        'track_name': title,
        if (duration != null) 'duration': duration.inSeconds.toString(),
      };

      final uri = Uri.https('lrclib.net', '/api/get', params);
      debugPrint('LRCLib attempt: $artist / $title -> $uri');

      final response = await http
          .get(uri, headers: {'Lrclib-Client': 'Track-n-Tube/1.0'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        final syncedLrc = data['syncedLyrics'] as String?;
        if (syncedLrc != null && syncedLrc.trim().isNotEmpty) {
          debugPrint('Found synced lyrics from LRCLib: $artist / $title');
          return SyncedLyrics.fromLrc(syncedLrc);
        }

        final plainLyrics = data['plainLyrics'] as String?;
        if (plainLyrics != null && plainLyrics.trim().isNotEmpty) {
          debugPrint('Found plain lyrics from LRCLib: $artist / $title');
          return SyncedLyrics.fromPlainText(_formatLyrics(plainLyrics));
        }
      } else {
        debugPrint('LRCLib miss (${response.statusCode}): $artist / $title');
      }
    } catch (e) {
      debugPrint('LRCLib error for "$artist" / "$title": $e');
    }
    return null;
  }

  static Future<SyncedLyrics?> _fetchPlainLyrics(
    String artist,
    String title,
  ) async {
    try {
      final uri = Uri(
        scheme: 'https',
        host: 'api.lyrics.ovh',
        pathSegments: ['v1', artist, title],
      );
      debugPrint('lyrics.ovh attempt: $artist / $title -> $uri');

      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final lyrics = data['lyrics'] as String?;
        if (lyrics != null && lyrics.trim().isNotEmpty) {
          debugPrint('Found lyrics from lyrics.ovh: $artist / $title');
          return SyncedLyrics.fromPlainText(_formatLyrics(lyrics));
        }
      } else {
        debugPrint(
          'lyrics.ovh miss (${response.statusCode}): $artist / $title',
        );
      }
    } catch (e) {
      debugPrint('lyrics.ovh error for "$artist" / "$title": $e');
    }
    return null;
  }

  static List<String> _extractTitleCandidates(String rawTitle) {
    final normalized = _normalizeSeparators(rawTitle);
    final pipeParts = normalized
        .split('|')
        .map(_cleanLooseSegment)
        .where((part) => part.isNotEmpty)
        .toList();
    if (pipeParts.isEmpty) return const [];

    final firstPart = pipeParts.first;
    final candidates = <String>[];

    void add(String value) {
      final cleaned = _cleanTitleForApi(value);
      if (cleaned.isNotEmpty && !candidates.contains(cleaned)) {
        candidates.add(cleaned);
      }
    }

    final dashParts = firstPart
        .split(RegExp(r'\s+-\s+'))
        .map(_cleanLooseSegment)
        .where((part) => part.isNotEmpty)
        .toList();

    if (dashParts.length >= 2) {
      final left = dashParts.first;
      final right = dashParts.sublist(1).join(' - ');

      if (_containsKnownSinger(left) && !_looksLikeMetadata(right)) {
        add(right);
        add(left);
      } else {
        add(left);
        if (!_looksLikeMetadata(right)) add(right);
      }
    } else {
      add(firstPart);
    }

    for (final part in pipeParts.skip(1)) {
      if (!_containsKnownSinger(part) && !_looksLikeMetadata(part)) {
        add(part);
      }
    }

    add(normalized);
    return candidates;
  }

  static List<String> _extractArtistsFromTitle(String rawTitle) {
    final normalized = _normalizeSeparators(rawTitle);
    final segments = normalized
        .split(RegExp(r'\||\s+-\s+|,|/'))
        .map(_cleanLooseSegment)
        .where((segment) => segment.isNotEmpty)
        .toList();
    final artists = <String>[];

    void add(String artist) {
      final cleaned = _cleanArtist(artist);
      if (cleaned.isNotEmpty &&
          !_isGenericArtist(cleaned) &&
          !artists.contains(cleaned)) {
        artists.add(cleaned);
      }
    }

    for (final segment in segments) {
      final lower = segment.toLowerCase();
      for (final singer in _knownSingers) {
        if (lower.contains(singer.toLowerCase())) {
          add(singer);
        }
      }

      final labelledArtist = RegExp(
        r'\b(?:singer|singers|vocal|vocals|artist|artists)\s*:\s*([a-z .&]+)',
        caseSensitive: false,
      ).firstMatch(segment);
      if (labelledArtist != null) {
        add(labelledArtist.group(1) ?? '');
      }
    }

    return artists;
  }

  static List<String> _expandTitleVariations(List<String> titles) {
    final variations = <String>[];

    void add(String value) {
      final cleaned = _cleanTitleForApi(value);
      if (cleaned.isNotEmpty && !variations.contains(cleaned)) {
        variations.add(cleaned);
      }
    }

    for (final title in titles) {
      add(title);

      final withoutFeatures = title
          .split(RegExp(r'\b(?:feat|ft|featuring)\b', caseSensitive: false))
          .first;
      add(withoutFeatures);

      final withoutSpecialCharacters = title.replaceAll(
        RegExp(r'[^A-Za-z0-9 ]+'),
        ' ',
      );
      add(withoutSpecialCharacters);

      add(title.toLowerCase());
    }

    return variations;
  }

  static List<String> _expandArtistVariations(List<String> artists) {
    final variations = <String>[];

    void add(String value) {
      final cleaned = _cleanArtist(value);
      if (cleaned.isNotEmpty && !variations.contains(cleaned)) {
        variations.add(cleaned);
      }
    }

    for (final artist in artists) {
      add(artist);

      final firstListedArtist = artist
          .split(
            RegExp(r'\s*(?:,|&|\+| x | and | with )\s*', caseSensitive: false),
          )
          .first;
      add(firstListedArtist);

      final words = artist.split(RegExp(r'\s+'));
      if (words.length > 2) {
        add(words.take(2).join(' '));
      }
    }

    return variations;
  }

  static String _cleanTitleForApi(String title) {
    var cleaned = _normalizeSeparators(title);
    cleaned = cleaned.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    cleaned = cleaned.replaceAll(
      RegExp("\\bfrom\\s+[\\\"']?[^|\\\"()]+", caseSensitive: false),
      ' ',
    );
    cleaned = cleaned.replaceAll(_noiseWords, ' ');
    cleaned = cleaned.replaceAll(RegExp(r'["`_]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.trim();
  }

  static String _cleanArtist(String artist) {
    var cleaned = _normalizeSeparators(artist);
    cleaned = cleaned.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), ' ');
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(?:official|topic|channel|vevo)\b', caseSensitive: false),
      ' ',
    );
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b(?:music|records|studios?|entertainment|songs)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    cleaned = cleaned.replaceAll(RegExp(r'["`_]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.trim();
  }

  static String _cleanLooseSegment(String value) {
    var cleaned = value.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'["`_]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.trim();
  }

  static String _normalizeSeparators(String value) {
    return value
        .replaceAll(RegExp('[\u2013\u2014]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _containsKnownSinger(String value) {
    final lower = value.toLowerCase();
    return _knownSingers.any((singer) => lower.contains(singer.toLowerCase()));
  }

  static bool _looksLikeMetadata(String value) {
    final lower = value.toLowerCase();
    if (_noiseWords.hasMatch(lower)) return true;
    if (_genericArtistWords.hasMatch(lower)) return true;

    final words = lower.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return words > 5;
  }

  static bool _isGenericArtist(String artist) {
    if (artist.trim().isEmpty) return true;
    return _genericArtistWords.hasMatch(artist.toLowerCase());
  }

  static String _formatLyrics(String rawLyrics) {
    final normalized = rawLyrics
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final lines = normalized
        .split('\n')
        .map((line) => line.trimRight())
        .toList();

    while (lines.isNotEmpty && lines.first.trim().isEmpty) {
      lines.removeAt(0);
    }

    if (lines.isNotEmpty && lines.first.toLowerCase().contains('paroles de')) {
      lines.removeAt(0);
    }

    final cleanedLines = <String>[];
    var blankRun = 0;
    for (final line in lines) {
      if (line.trim().isEmpty) {
        blankRun++;
        if (blankRun <= 1) cleanedLines.add('');
      } else {
        blankRun = 0;
        cleanedLines.add(line);
      }
    }

    return cleanedLines.join('\n').trim();
  }
}
