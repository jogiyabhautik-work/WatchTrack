import 'package:flutter_test/flutter_test.dart';
import 'package:watch_track/core/services/lyrics_service.dart';

void main() {
  group('LyricsService.buildLookupAttempts', () {
    test('keeps song title before movie metadata and extracts singer', () {
      final attempts = LyricsService.buildLookupAttempts(
        'T-Series',
        'Kesariya - Brahmastra | Arijit Singh | Pritam',
      );

      expect(attempts, isNotEmpty);
      expect(attempts.first.artist, 'Arijit Singh');
      expect(attempts.first.title, 'Kesariya');
    });

    test('removes official video text and keeps title before dash', () {
      final attempts = LyricsService.buildLookupAttempts(
        'Zee Music Company',
        'Apna Bana Le - Bhediya | Arijit Singh | Official Video',
      );

      expect(attempts.first.artist, 'Arijit Singh');
      expect(attempts.first.title, 'Apna Bana Le');
      expect(
        attempts.any(
          (attempt) => attempt.title.toLowerCase().contains('official'),
        ),
        isFalse,
      );
    });

    test('does not treat actor/movie metadata as the lyric title', () {
      final attempts = LyricsService.buildLookupAttempts(
        'YRF',
        'Jhoome Jo Pathaan - Shah Rukh Khan | Arijit Singh | 4K',
      );

      expect(attempts.first.artist, 'Arijit Singh');
      expect(attempts.first.title, 'Jhoome Jo Pathaan');
    });

    test('falls back to common artists when no singer is available', () {
      final attempts = LyricsService.buildLookupAttempts(
        'YouTube Video',
        'Unknown Song Title (Video Song) | Official Audio',
      );

      expect(attempts, isNotEmpty);
      expect(attempts.first.title, 'Unknown Song Title');
      expect(attempts.first.artist, 'Arijit Singh');
    });
  });
}
