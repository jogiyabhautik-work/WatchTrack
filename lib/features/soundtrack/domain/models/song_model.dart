import 'package:watch_track/features/soundtrack/domain/enums/song_source.dart';
import 'package:watch_track/features/soundtrack/domain/enums/song_type.dart';

class SongModel {
  final String id;
  final String title;
  final String artist;
  final SongType type;
  final String? episode;
  final String? season;
  final SongSource source;
  final String? externalUrl;
  final String? thumbnailUrl;
  final String? duration;

  SongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.type,
    this.episode,
    this.season,
    required this.source,
    this.externalUrl,
    this.thumbnailUrl,
    this.duration,
  });

  // Factory to safely handle unknown or empty values from APIs
  factory SongModel.create({
    required String id,
    required String title,
    String? artist,
    required SongType type,
    String? episode,
    String? season,
    required SongSource source,
    String? externalUrl,
    String? thumbnailUrl,
    String? duration,
  }) {
    return SongModel(
      id: id,
      title: title.isEmpty ? 'Unknown Title' : title,
      artist: (artist == null || artist.isEmpty) ? 'Unknown Artist' : artist,
      type: type,
      episode: episode,
      season: season,
      source: source,
      externalUrl: externalUrl,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
    );
  }
}
