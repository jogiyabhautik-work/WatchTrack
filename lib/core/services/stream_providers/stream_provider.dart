import 'package:watch_track/data/models/movie_model.dart';

class StreamQuality {
  final String quality;
  final String url;
  final dynamic extraStreamInfo;
  final String? youtubeVideoId;

  StreamQuality({required this.quality, required this.url, this.extraStreamInfo, this.youtubeVideoId});
}

class StreamVideoData {
  final String id;
  final String title;
  final String language;
  final List<StreamQuality> qualities;
  final String sourceName; // e.g. YouTube, VidSrc
  final Duration? duration;
  final String? thumbnailUrl;

  StreamVideoData({
    required this.id,
    required this.title,
    required this.language,
    required this.qualities,
    required this.sourceName,
    this.duration,
    this.thumbnailUrl,
  });
}

abstract class StreamProvider {
  String get providerName;
  Future<List<StreamVideoData>> getStreams(Movie movie);
}
