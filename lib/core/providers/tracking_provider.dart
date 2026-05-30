import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:appwrite/appwrite.dart';
import 'package:watch_track/core/appwrite_client.dart';
import 'package:watch_track/core/appwrite_constants.dart';
import 'package:watch_track/data/models/user_title_model.dart';
import 'package:watch_track/data/models/movie_model.dart';
import 'package:watch_track/core/providers/sync_provider.dart';
import 'package:watch_track/data/models/sync_action_model.dart';

class TrackingProvider extends ChangeNotifier {
  Map<int, UserTitle> _trackedTitles = {};
  static const String _storageKey = 'tracking_data';

  final Databases _databases = Databases(client);
  String? _currentUserId;
  SyncProvider? _syncProvider;

  TrackingProvider() {
    _loadData();
  }

  void clearData() {
    _trackedTitles.clear();
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) => prefs.remove(_storageKey));
  }

  void setUserId(String? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      if (userId != null) {
        syncFromAppwrite().then((_) {
           syncPendingItems();
           migrateFromLegacy();
        });
      } else {
        clearData();
      }
    }
  }

  Future<void> migrateFromLegacy() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Migrate Favorites
    final favoritesStr = prefs.getString('user_favorite_movies');
    if (favoritesStr != null) {
      final List decoded = json.decode(favoritesStr);
      final List<String> favoriteIds = decoded.map((e) => e.toString()).toList();
      
      bool changed = false;
      for (var idStr in favoriteIds) {
        final id = int.tryParse(idStr) ?? 0;
        if (id == 0) continue;
        
        final existing = _trackedTitles[id];
        if (existing == null) {
           // We don't have the full movie object here easily, 
           // but we can create a shell if we want, or just wait for them to visit the page.
           // Better to just migrate existing tracked titles' favorite status.
        } else if (!existing.isFavorite) {
          _trackedTitles[id] = existing.copyWith(isFavorite: true, updatedAt: DateTime.now(), syncStatus: SyncStatus.pending);
          changed = true;
        }
      }
      if (changed) {
        notifyListeners();
        _saveData();
      }
      // Remove legacy key after migration
      await prefs.remove('user_favorite_movies');
    }

    // Migrate Ratings
    final ratingsStr = prefs.getString('user_ratings');
    if (ratingsStr != null) {
      final Map<String, dynamic> decoded = json.decode(ratingsStr);
      bool changed = false;
      decoded.forEach((idStr, rating) {
        final id = int.tryParse(idStr) ?? 0;
        if (id == 0) return;
        final existing = _trackedTitles[id];
        if (existing != null && existing.userRating == null) {
          _trackedTitles[id] = existing.copyWith(userRating: (rating as num).toDouble(), updatedAt: DateTime.now(), syncStatus: SyncStatus.pending);
          changed = true;
        }
      });
      if (changed) {
        notifyListeners();
        _saveData();
      }
      await prefs.remove('user_ratings');
    }
  }

  void setSyncProvider(SyncProvider syncProvider) {
    _syncProvider = syncProvider;
  }

  Map<int, UserTitle> get trackedTitles => _trackedTitles;
  List<UserTitle> get allTracked => _trackedTitles.values.toList();

  UserTitle? getTracking(int tmdbId) => _trackedTitles[tmdbId];

  Future<void> updateStatus(
    Movie movie,
    TrackingStatus status, {
    int? progress,
    double? rating,
  }) async {
    final int id = int.tryParse(movie.id) ?? 0;
    if (id == 0) return;

    final existing = _trackedTitles[id];

    _trackedTitles[id] = UserTitle(
      tmdbId: id,
      mediaType: movie.isMovie ? 'movie' : 'tv',
      title: movie.title,
      posterPath: movie.posterPath,
      backdropPath: movie.backdropPath,
      overview: movie.overview,
      status: status,
      progressPercent: progress ?? existing?.progressPercent ?? 0,
      userRating: rating ?? existing?.userRating,
      isFavorite: existing?.isFavorite ?? false,
      lastSeason: existing?.lastSeason ?? 0,
      lastEpisode: existing?.lastEpisode ?? 0,
      totalEpisodes: existing?.totalEpisodes ?? 0,
      watchedEpisodes: existing?.watchedEpisodes ?? [],
      notes: existing?.notes,
      priority: existing?.priority ?? 'Medium',
      tags: existing?.tags ?? [],
      rewatchCount: existing?.rewatchCount ?? 0,
      watchedAt: status == TrackingStatus.watched
          ? (existing?.watchedAt ?? DateTime.now())
          : existing?.watchedAt,
      addedAt: existing?.addedAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    notifyListeners();
    _saveData();
    _triggerSync(_trackedTitles[id]!);
  }

  Future<void> updateTrackingDetails({
    required int tmdbId,
    TrackingStatus? status,
    int? progress,
    double? rating,
    String? notes,
    String? priority,
    List<String>? tags,
    int? rewatchCount,
    int? lastSeason,
    int? lastEpisode,
    int? totalEpisodes,
    List<String>? watchedEpisodes,
    bool? isFavorite,
    String? backdropPath,
    String? overview,
  }) async {
    final existing = _trackedTitles[tmdbId];
    if (existing == null) return;

    _trackedTitles[tmdbId] = UserTitle(
      tmdbId: tmdbId,
      mediaType: existing.mediaType,
      title: existing.title,
      posterPath: existing.posterPath,
      backdropPath: backdropPath ?? existing.backdropPath,
      overview: overview ?? existing.overview,
      status: status ?? existing.status,
      progressPercent: progress ?? existing.progressPercent,
      userRating: rating ?? existing.userRating,
      isFavorite: isFavorite ?? existing.isFavorite,
      lastSeason: lastSeason ?? existing.lastSeason,
      lastEpisode: lastEpisode ?? existing.lastEpisode,
      totalEpisodes: totalEpisodes ?? existing.totalEpisodes,
      watchedEpisodes: watchedEpisodes ?? existing.watchedEpisodes,
      notes: notes ?? existing.notes,
      priority: priority ?? existing.priority,
      tags: tags ?? existing.tags,
      rewatchCount: rewatchCount ?? existing.rewatchCount,
      watchedAt:
          (status == TrackingStatus.watched &&
              existing.status != TrackingStatus.watched)
          ? DateTime.now()
          : existing.watchedAt,
      addedAt: existing.addedAt,
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    notifyListeners();
    _saveData();
    _triggerSync(_trackedTitles[tmdbId]!);
  }

  Future<void> toggleFavorite(Movie movie) async {
    final int id = int.tryParse(movie.id) ?? 0;
    if (id == 0) return;

    final existing = _trackedTitles[id];
    final bool newFavorite = !(existing?.isFavorite ?? false);

    if (existing == null) {
      // If not tracked yet, add to watchlist and favorite it
      _trackedTitles[id] = UserTitle(
        tmdbId: id,
        mediaType: movie.isMovie ? 'movie' : 'tv',
        title: movie.title,
        posterPath: movie.posterPath,
        backdropPath: movie.backdropPath,
        overview: movie.overview,
        status: TrackingStatus.watchlist,
        isFavorite: true,
        addedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.pending,
      );
    } else {
      _trackedTitles[id] = existing.copyWith(
        isFavorite: newFavorite,
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.pending,
      );
    }

    notifyListeners();
    _saveData();
    _triggerSync(_trackedTitles[id]!);
  }

  Future<void> rateMovie(Movie movie, double rating) async {
    final int id = int.tryParse(movie.id) ?? 0;
    if (id == 0) return;

    final existing = _trackedTitles[id];

    if (existing == null) {
      // If not tracked yet, add to watchlist and rate it
      _trackedTitles[id] = UserTitle(
        tmdbId: id,
        mediaType: movie.isMovie ? 'movie' : 'tv',
        title: movie.title,
        posterPath: movie.posterPath,
        backdropPath: movie.backdropPath,
        overview: movie.overview,
        status: TrackingStatus.watchlist,
        userRating: rating,
        addedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.pending,
      );
    } else {
      _trackedTitles[id] = existing.copyWith(
        userRating: rating,
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.pending,
      );
    }

    notifyListeners();
    _saveData();
    _triggerSync(_trackedTitles[id]!);
  }

  Future<void> toggleEpisode(
    Movie movie,
    int season,
    int episode,
    int totalEpisodes,
  ) async {
    final int id = int.tryParse(movie.id) ?? 0;
    if (id == 0) return;

    final existing = _trackedTitles[id];
    final epKey = "S${season}E${episode}";

    List<String> watched = List.from(existing?.watchedEpisodes ?? []);
    if (watched.contains(epKey)) {
      watched.remove(epKey);
    } else {
      watched.add(epKey);
    }

    final effectiveTotal = totalEpisodes > 0
        ? totalEpisodes
        : (existing?.totalEpisodes ?? 0);
    final newProgress = effectiveTotal > 0
        ? ((watched.length / effectiveTotal) * 100).round()
        : 0;
    final clampedProgress = newProgress.clamp(0, 100);
    final newStatus = watched.isEmpty
        ? TrackingStatus.watchlist
        : (clampedProgress >= 100
              ? TrackingStatus.watched
              : TrackingStatus.watching);

    _trackedTitles[id] = UserTitle(
      tmdbId: id,
      mediaType: 'tv',
      title: movie.title,
      posterPath: movie.posterPath,
      backdropPath: existing != null && existing.backdropPath.isNotEmpty
          ? existing.backdropPath
          : movie.backdropPath,
      overview: existing != null && existing.overview.isNotEmpty
          ? existing.overview
          : movie.overview,
      status: newStatus,
      progressPercent: clampedProgress,
      userRating: existing?.userRating,
      isFavorite: existing?.isFavorite ?? false,
      lastSeason: season,
      lastEpisode: episode,
      totalEpisodes: effectiveTotal,
      watchedEpisodes: watched,
      notes: existing?.notes,
      priority: existing?.priority ?? 'Medium',
      tags: existing?.tags ?? [],
      rewatchCount: existing?.rewatchCount ?? 0,
      watchedAt: newStatus == TrackingStatus.watched
          ? (existing?.watchedAt ?? DateTime.now())
          : existing?.watchedAt,
      addedAt: existing?.addedAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    notifyListeners();
    _saveData();
    _triggerSync(_trackedTitles[id]!);
  }

  Future<void> syncPendingItems() async {
    if (_currentUserId == null || _syncProvider == null) return;
    
    final pending = _trackedTitles.values.where((t) => t.syncStatus == SyncStatus.pending).toList();
    if (pending.isEmpty) return;

    debugPrint('🔄 Syncing ${pending.length} pending items to cloud...');
    for (var item in pending) {
      _triggerSync(item);
    }
  }

  Future<void> removeTracking(int tmdbId) async {
    final title = _trackedTitles[tmdbId];
    _trackedTitles.remove(tmdbId);
    notifyListeners();
    _saveData();
    if (title != null) _triggerDelete(title);
  }

  void _triggerDelete(UserTitle title) {
    if (_currentUserId == null || _syncProvider == null) return;
    
    _syncProvider!.addToQueue(
      userId: _currentUserId!,
      itemId: title.tmdbId,
      mediaType: title.mediaType,
      actionType: SyncActionType.deleteTracking,
      payload: {
        AppwriteConstants.attrUserId: _currentUserId,
        AppwriteConstants.attrTmdbId: title.tmdbId,
      },
    );
  }

  void _triggerSync(UserTitle title) {
    if (_currentUserId == null || _syncProvider == null) return;

    final data = {
      AppwriteConstants.attrUserId: _currentUserId,
      AppwriteConstants.attrTmdbId: title.tmdbId,
      AppwriteConstants.attrTitle: title.title,
      AppwriteConstants.attrPosterPath: title.posterPath,
      AppwriteConstants.attrBackdropPath: title.backdropPath,
      AppwriteConstants.attrOverview: title.overview,
      AppwriteConstants.attrMediaType: title.mediaType,
      AppwriteConstants.attrStatus: title.status.name,
      AppwriteConstants.attrUserRating: title.userRating,
      AppwriteConstants.attrProgress: title.progressPercent,
      AppwriteConstants.attrTotalEpisodes: title.totalEpisodes,
      AppwriteConstants.attrWatchedEpisodes: title.watchedEpisodes,
      AppwriteConstants.attrLastSeason: title.lastSeason,
      AppwriteConstants.attrLastEpisode: title.lastEpisode,
      AppwriteConstants.attrIsFavorite: title.isFavorite,
      AppwriteConstants.attrNotes: title.notes,
      AppwriteConstants.attrPriority: title.priority,
      AppwriteConstants.attrTags: title.tags,
      AppwriteConstants.attrRewatchCount: title.rewatchCount,
      AppwriteConstants.attrWatchedAt: title.watchedAt?.toIso8601String(),
      AppwriteConstants.attrAddedAt: title.addedAt.toIso8601String(),
      AppwriteConstants.attrUpdatedAt: title.updatedAt.toIso8601String(),
    };

    _syncProvider!.addToQueue(
      userId: _currentUserId!,
      itemId: title.tmdbId,
      mediaType: title.mediaType,
      actionType: SyncActionType.updateTracking,
      payload: data,
    ).then((_) {
       // Optionally update local status to syncing if we want very granular UI
    });
  }

  Future<void> syncFromAppwrite() async {
    if (_currentUserId == null) return;

    try {
      final response = await _databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.trackingCollectionId,
        queries: [Query.equal(AppwriteConstants.attrUserId, _currentUserId!)],
      );

      for (var doc in response.documents) {
        final cloudUpdatedAt = DateTime.tryParse(doc.data[AppwriteConstants.attrUpdatedAt] ?? '') ?? DateTime.now();
        final tmdbId = doc.data[AppwriteConstants.attrTmdbId];
        final existing = _trackedTitles[tmdbId];

        // Conflict Resolution: Local wins if it's newer
        if (existing != null && existing.updatedAt.isAfter(cloudUpdatedAt)) {
          debugPrint('Conflict: Local is newer for $tmdbId, skipping cloud update.');
          continue;
        }

        final title = UserTitle(
          tmdbId: tmdbId,
          mediaType: doc.data[AppwriteConstants.attrMediaType],
          title: doc.data[AppwriteConstants.attrTitle],
          posterPath: doc.data[AppwriteConstants.attrPosterPath],
          backdropPath: doc.data[AppwriteConstants.attrBackdropPath] ?? '',
          overview: doc.data[AppwriteConstants.attrOverview] ?? '',
          status: TrackingStatus.values.firstWhere(
            (s) => s.name == doc.data[AppwriteConstants.attrStatus],
            orElse: () => TrackingStatus.watchlist,
          ),
          progressPercent: doc.data[AppwriteConstants.attrProgress] ?? 0,
          userRating: (doc.data[AppwriteConstants.attrUserRating] as num?)
              ?.toDouble(),
          totalEpisodes: doc.data[AppwriteConstants.attrTotalEpisodes] ?? 0,
          watchedEpisodes:
              (doc.data[AppwriteConstants.attrWatchedEpisodes] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
          lastSeason: doc.data[AppwriteConstants.attrLastSeason] ?? 0,
          lastEpisode: doc.data[AppwriteConstants.attrLastEpisode] ?? 0,
          isFavorite: doc.data[AppwriteConstants.attrIsFavorite] ?? false,
          notes: doc.data[AppwriteConstants.attrNotes],
          priority: doc.data[AppwriteConstants.attrPriority] ?? 'Medium',
          tags:
              (doc.data[AppwriteConstants.attrTags] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
          rewatchCount: doc.data[AppwriteConstants.attrRewatchCount] ?? 0,
          watchedAt: doc.data[AppwriteConstants.attrWatchedAt] != null
              ? DateTime.parse(doc.data[AppwriteConstants.attrWatchedAt])
              : null,
          addedAt: doc.data[AppwriteConstants.attrAddedAt] != null
              ? DateTime.parse(doc.data[AppwriteConstants.attrAddedAt])
              : DateTime.now(),
          updatedAt: cloudUpdatedAt,
          syncStatus: SyncStatus.synced,
          lastSyncedAt: DateTime.now(),
        );
        _trackedTitles[title.tmdbId] = title;
      }
      notifyListeners();
      _saveData();
    } catch (e) {
      debugPrint('Appwrite Load Error: $e');
    }
  }

  Future<void> refresh() async {
    if (_currentUserId != null) {
      await syncFromAppwrite();
      await syncPendingItems();
    }
    notifyListeners();
  }

  void _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _trackedTitles.map(
      (key, value) => MapEntry(key.toString(), value.toJson()),
    );
    await prefs.setString(_storageKey, json.encode(data));
  }

  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_storageKey);
    if (encoded != null) {
      final Map<String, dynamic> decoded = json.decode(encoded);
      _trackedTitles = decoded.map(
        (key, value) => MapEntry(int.parse(key), UserTitle.fromJson(value)),
      );
      notifyListeners();
    }
  }
}
