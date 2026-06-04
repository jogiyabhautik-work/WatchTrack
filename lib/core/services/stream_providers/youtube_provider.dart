import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:watch_track/core/services/stream_providers/stream_provider.dart';
import 'package:watch_track/data/models/movie_model.dart';
import 'package:flutter/foundation.dart';

class YouTubeProvider implements StreamProvider {
  @override
  String get providerName => 'YouTube';

  final YoutubeExplode _yt = YoutubeExplode();

  @override
  Future<List<StreamVideoData>> getStreams(Movie movie) async {
    final List<StreamVideoData> validStreams = [];
    try {
      final year = movie.releaseDate.isNotEmpty ? movie.releaseDate.substring(0, 4) : '';
      final searchQuery = '${movie.title} $year full movie';
      final searchResults = await _yt.search.search(searchQuery);

      // Parse target duration
      final targetDuration = int.tryParse(movie.runtime.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

      for (var video in searchResults.take(30)) {
        if (video.duration != null) {
          final t = video.title.toLowerCase();
          
          // Reject typical non-movie YouTube videos (reviews, recaps, podcasts, music, etc.)
          if (t.contains('reaction') || t.contains('review') || 
              t.contains('recap') || t.contains('explained') || 
              t.contains('trailer') || t.contains('teaser') ||
              t.contains('podcast') || t.contains('breakdown') || 
              t.contains('interview') || t.contains('behind the scenes') ||
              t.contains('making of') || t.contains('soundtrack') || 
              t.contains('ost') || t.contains('mix') || t.contains('album') ||
              t.contains('playlist') || t.contains('parody') || t.contains('fanmade') || 
              t.contains('concept') || t.contains('gameplay') || t.contains('cutscenes')) {
            continue;
          }

          final diff = (video.duration!.inMinutes - targetDuration).abs();
          // If TMDB runtime is unknown (0), assume any video over 60 mins is a movie.
          // Otherwise, allow up to 45 mins difference.
          if (targetDuration == 0 ? video.duration!.inMinutes >= 60 : diff <= 45) {
            // Found a full movie match! Now extract the stream URL
            try {
              final manifest = await _yt.videos.streamsClient.getManifest(video.id);
              final muxedStreams = manifest.muxed.sortByVideoQuality();
              
              if (muxedStreams.isNotEmpty) {
                final List<StreamQuality> qualities = [];
                for (var streamInfo in muxedStreams) {
                  qualities.add(StreamQuality(
                    quality: streamInfo.videoQuality.name.toUpperCase(),
                    url: streamInfo.url.toString(),
                    extraStreamInfo: streamInfo,
                    youtubeVideoId: video.id.value,
                  ));
                }

                if (qualities.isNotEmpty) {
                  // Determine language based on title/description heuristically
                  String detectedLanguage = _detectLanguage(video.title, video.description);
                  
                  validStreams.add(StreamVideoData(
                    id: video.id.value,
                    title: video.title,
                    language: detectedLanguage,
                    qualities: qualities,
                    sourceName: providerName,
                    duration: video.duration,
                    thumbnailUrl: video.thumbnails.highResUrl,
                  ));
                }
              }
            } catch (e) {
              debugPrint('Error extracting YouTube stream: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error searching YouTube streams: $e');
    }
    return validStreams;
  }

  String _detectLanguage(String title, String description) {
    final t = title.toLowerCase();
    final d = description.toLowerCase();
    if (t.contains('hindi') || d.contains('hindi dub')) return 'Hindi';
    if (t.contains('spanish') || t.contains('español')) return 'Spanish';
    if (t.contains('tamil')) return 'Tamil';
    if (t.contains('telugu')) return 'Telugu';
    if (t.contains('french') || t.contains('français')) return 'French';
    return 'Original'; // Fallback
  }
}
