

enum TrackingStatus {
  watchlist,
  watching,
  watched,
  onHold,
  dropped,
  rewatching;

  String get displayName {
    switch (this) {
      case TrackingStatus.watchlist: return 'Plan to Watch';
      case TrackingStatus.watching: return 'Watching';
      case TrackingStatus.watched: return 'Watched';
      case TrackingStatus.onHold: return 'On Hold';
      case TrackingStatus.dropped: return 'Dropped';
      case TrackingStatus.rewatching: return 'Rewatching';
    }
  }
}

enum SyncStatus {
  synced,
  pending,
  syncing,
  failed
}

class UserTitle {
  final int tmdbId;
  final String mediaType; // 'movie' or 'tv'
  final String title;
  final String posterPath;
  final String backdropPath;
  final String overview;
  final TrackingStatus status;
  final int progressPercent;
  final double? userRating;
  final bool isFavorite;
  final int lastSeason;
  final int lastEpisode;
  final int totalEpisodes;
  final List<String> watchedEpisodes; 
  final String? notes;
  final String priority; // Low, Medium, High
  final List<String> tags;
  final int rewatchCount;
  final DateTime? watchedAt;
  final DateTime addedAt;
  final DateTime updatedAt;
  
  // Sync Fields
  final SyncStatus syncStatus;
  final DateTime? lastSyncedAt;
  final int retryCount;
  final String? cloudErrorMessage;

  UserTitle({
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    required this.posterPath,
    this.backdropPath = '',
    this.overview = '',
    required this.status,
    this.progressPercent = 0,
    this.userRating,
    this.isFavorite = false,
    this.lastSeason = 0,
    this.lastEpisode = 0,
    this.totalEpisodes = 0,
    this.watchedEpisodes = const [],
    this.notes,
    this.priority = 'Medium',
    this.tags = const [],
    this.rewatchCount = 0,
    this.watchedAt,
    required this.addedAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.synced,
    this.lastSyncedAt,
    this.retryCount = 0,
    this.cloudErrorMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'tmdb_id': tmdbId,
      'media_type': mediaType,
      'title': title,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'overview': overview,
      'status': status.name,
      'progress_percent': progressPercent,
      'user_rating': userRating,
      'is_favorite': isFavorite,
      'last_season': lastSeason,
      'last_episode': lastEpisode,
      'total_episodes': totalEpisodes,
      'watched_episodes': watchedEpisodes,
      'notes': notes,
      'priority': priority,
      'tags': tags,
      'rewatch_count': rewatchCount,
      'watched_at': watchedAt?.toIso8601String(),
      'added_at': addedAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus.name,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'retry_count': retryCount,
      'cloud_error_message': cloudErrorMessage,
    };
  }

  factory UserTitle.fromJson(Map<String, dynamic> json) {
    return UserTitle(
      tmdbId: json['tmdb_id'],
      mediaType: json['media_type'],
      title: json['title'],
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'] ?? '',
      overview: json['overview'] ?? '',
      status: TrackingStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => TrackingStatus.watchlist),
      progressPercent: json['progress_percent'] ?? 0,
      userRating: (json['user_rating'] is num) ? (json['user_rating'] as num).toDouble() : null,
      isFavorite: json['is_favorite'] ?? false,
      lastSeason: json['last_season'] ?? 0,
      lastEpisode: json['last_episode'] ?? 0,
      totalEpisodes: json['total_episodes'] ?? 0,
      watchedEpisodes: (json['watched_episodes'] as List?)?.map((e) => e.toString()).toList() ?? [],
      notes: json['notes'],
      priority: json['priority'] ?? 'Medium',
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      rewatchCount: json['rewatch_count'] ?? 0,
      watchedAt: json['watched_at'] != null ? DateTime.parse(json['watched_at']) : null,
      addedAt: json['added_at'] != null ? DateTime.parse(json['added_at']) : DateTime.now(),
      updatedAt: DateTime.parse(json['updated_at']),
      syncStatus: SyncStatus.values.firstWhere((e) => e.name == json['sync_status'], orElse: () => SyncStatus.synced),
      lastSyncedAt: json['last_synced_at'] != null ? DateTime.parse(json['last_synced_at']) : null,
      retryCount: json['retry_count'] ?? 0,
      cloudErrorMessage: json['cloud_error_message'],
    );
  }

  UserTitle copyWith({
    int? tmdbId,
    String? mediaType,
    String? title,
    String? posterPath,
    String? backdropPath,
    String? overview,
    TrackingStatus? status,
    int? progressPercent,
    double? userRating,
    bool? isFavorite,
    int? lastSeason,
    int? lastEpisode,
    int? totalEpisodes,
    List<String>? watchedEpisodes,
    String? notes,
    String? priority,
    List<String>? tags,
    int? rewatchCount,
    DateTime? watchedAt,
    DateTime? addedAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
    DateTime? lastSyncedAt,
    int? retryCount,
    String? cloudErrorMessage,
  }) {
    return UserTitle(
      tmdbId: tmdbId ?? this.tmdbId,
      mediaType: mediaType ?? this.mediaType,
      title: title ?? this.title,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      overview: overview ?? this.overview,
      status: status ?? this.status,
      progressPercent: progressPercent ?? this.progressPercent,
      userRating: userRating ?? this.userRating,
      isFavorite: isFavorite ?? this.isFavorite,
      lastSeason: lastSeason ?? this.lastSeason,
      lastEpisode: lastEpisode ?? this.lastEpisode,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      watchedEpisodes: watchedEpisodes ?? this.watchedEpisodes,
      notes: notes ?? this.notes,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      rewatchCount: rewatchCount ?? this.rewatchCount,
      watchedAt: watchedAt ?? this.watchedAt,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      retryCount: retryCount ?? this.retryCount,
      cloudErrorMessage: cloudErrorMessage ?? this.cloudErrorMessage,
    );
  }
}
