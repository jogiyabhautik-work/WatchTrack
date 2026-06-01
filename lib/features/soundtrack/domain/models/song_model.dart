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
  
  // New Properties for Advanced Player Support
  final String? subtitle;
  final String? contentTitle;
  final String? contentType;
  final String? mediaType;
  final String? language;
  final String? channelName;
  final bool isOfficial;
  final bool isLikelyAccurate;
  final double confidenceScore;
  final String? reason;
  final List<String> availableModes;

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
    this.subtitle,
    this.contentTitle,
    this.contentType,
    this.mediaType,
    this.language,
    this.channelName,
    this.isOfficial = false,
    this.isLikelyAccurate = true,
    this.confidenceScore = 1.0,
    this.reason,
    this.availableModes = const ['audio', 'video'],
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
    String? subtitle,
    String? contentTitle,
    String? contentType,
    String? mediaType,
    String? language,
    String? channelName,
    bool isOfficial = false,
    bool isLikelyAccurate = true,
    double confidenceScore = 1.0,
    String? reason,
    List<String> availableModes = const ['audio', 'video'],
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
      subtitle: subtitle,
      contentTitle: contentTitle,
      contentType: contentType,
      mediaType: mediaType,
      language: language,
      channelName: channelName,
      isOfficial: isOfficial,
      isLikelyAccurate: isLikelyAccurate,
      confidenceScore: confidenceScore,
      reason: reason,
      availableModes: availableModes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'type': type.toString(),
      'episode': episode,
      'season': season,
      'source': source.toString(),
      'externalUrl': externalUrl,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'subtitle': subtitle,
      'contentTitle': contentTitle,
      'contentType': contentType,
      'mediaType': mediaType,
      'language': language,
      'channelName': channelName,
      'isOfficial': isOfficial,
      'isLikelyAccurate': isLikelyAccurate,
      'confidenceScore': confidenceScore,
      'reason': reason,
      'availableModes': availableModes,
    };
  }

  factory SongModel.fromJson(Map<String, dynamic> json) {
    return SongModel(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Unknown Title',
      artist: json['artist'] ?? 'Unknown Artist',
      type: SongType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => SongType.soundtrack,
      ),
      episode: json['episode'],
      season: json['season'],
      source: SongSource.values.firstWhere(
        (e) => e.toString() == json['source'],
        orElse: () => SongSource.youtube,
      ),
      externalUrl: json['externalUrl'],
      thumbnailUrl: json['thumbnailUrl'],
      duration: json['duration'],
      subtitle: json['subtitle'],
      contentTitle: json['contentTitle'],
      contentType: json['contentType'],
      mediaType: json['mediaType'],
      language: json['language'],
      channelName: json['channelName'],
      isOfficial: json['isOfficial'] ?? false,
      isLikelyAccurate: json['isLikelyAccurate'] ?? true,
      confidenceScore: (json['confidenceScore'] ?? 1.0) as double,
      reason: json['reason'],
      availableModes: json['availableModes'] != null
          ? List<String>.from(json['availableModes'])
          : const ['audio', 'video'],
    );
  }
}
