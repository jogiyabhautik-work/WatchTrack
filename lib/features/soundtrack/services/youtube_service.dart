import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:watch_track/features/soundtrack/domain/models/song_model.dart';
import 'package:watch_track/features/soundtrack/domain/enums/song_type.dart';
import 'package:watch_track/features/soundtrack/domain/enums/song_source.dart';

class YouTubeService {
  final YoutubeExplode _yt = YoutubeExplode();

  Future<List<SongModel>> getSoundtrackForMedia(String title, bool isMovie) async {
    try {
      final query = isMovie ? '$title movie soundtrack full' : '$title tv series soundtrack';
      
      final searchResults = await _yt.search.search(query);
      if (searchResults.isEmpty) {
        return [];
      }

      List<SongModel> songs = [];
      
      // Filter out long videos (e.g. full albums > 10 mins) and unwanted keywords
      final filteredResults = searchResults.where((video) {
        final duration = video.duration;
        if (duration == null) return false;
        if (duration.inMinutes > 10) return false;
        
        final title = video.title.toLowerCase();
        if (title.contains('full album') || 
            title.contains('compilation') || 
            title.contains('playlist') || 
            title.contains('trailer') || 
            title.contains('review')) {
          return false;
        }
        return true;
      }).take(15).toList();

      for (var video in filteredResults) {
        songs.add(
          SongModel.create(
            id: video.id.value,
            title: video.title,
            artist: video.author,
            type: SongType.soundtrack,
            source: SongSource.youtube,
            externalUrl: video.url,
            thumbnailUrl: video.thumbnails.highResUrl,
            duration: video.duration?.toString().split('.').first ?? '', // Format: H:MM:SS or MM:SS
          ),
        );
      }

      return songs;
    } catch (e) {
      debugPrint('Exception in YouTubeService: $e');
      return [];
    }
  }

  /// Extracts the direct audio stream URL for a given YouTube Video ID
  Future<String?> getAudioStreamUrl(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      
      // Android MediaPlayer (used by audioplayers) crashes with MEDIA_ERROR_UNKNOWN on WebM/Opus streams.
      // We explicitly filter for mp4 (m4a/aac) which has native hardware support.
      final compatibleStreams = manifest.audioOnly.where(
        (stream) => stream.container.name == 'mp4' || stream.container.name == 'm4a'
      );
      
      if (compatibleStreams.isNotEmpty) {
        return compatibleStreams.withHighestBitrate().url.toString();
      }
      
      // Fallback if no mp4 stream is found
      return manifest.audioOnly.withHighestBitrate().url.toString();
    } catch (e) {
      debugPrint('Exception extracting audio stream: $e');
      return null;
    }
  }

  void dispose() {
    _yt.close();
  }
}
