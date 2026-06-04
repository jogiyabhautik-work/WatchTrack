import 'package:watch_track/data/models/movie_model.dart';
import 'package:watch_track/core/services/stream_providers/stream_provider.dart';
import 'package:watch_track/core/services/stream_providers/youtube_provider.dart';
import 'package:watch_track/core/services/stream_providers/web_provider.dart';

class FreeStreamService {
  final List<StreamProvider> _providers = [
    YouTubeProvider(),
    WebScraperProvider(),
  ];

  Future<List<StreamVideoData>> getAllAvailableStreams(Movie movie) async {
    List<StreamVideoData> allStreams = [];
    
    // Execute all providers concurrently for speed
    final futures = _providers.map((provider) => provider.getStreams(movie));
    final results = await Future.wait(futures);
    
    for (var result in results) {
      allStreams.addAll(result);
    }
    
    // Sort internal qualities for each video (highest first)
    final qualityOrder = {'1080P': 4, '720P': 3, '480P': 2, '360P': 1};
    for (var stream in allStreams) {
      stream.qualities.sort((a, b) {
        final aQ = qualityOrder[a.quality.toUpperCase()] ?? 0;
        final bQ = qualityOrder[b.quality.toUpperCase()] ?? 0;
        return bQ.compareTo(aQ);
      });
    }

    return allStreams;
  }
}
