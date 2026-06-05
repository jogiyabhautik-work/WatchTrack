import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:appwrite/appwrite.dart';
import 'package:watch_track/core/appwrite_client.dart';
import 'package:watch_track/core/appwrite_constants.dart';
import 'package:watch_track/core/providers/sync_provider.dart';
import 'package:watch_track/data/models/sync_action_model.dart';

class WatchlistFolder {
  final String id;
  String name;
  String emoji;
  final DateTime createdAt;
  List<String> movieIds; // TMDb IDs
  List<String> movieData; // JSON strings of basic movie info

  WatchlistFolder({
    required this.id,
    required this.name,
    required this.emoji,
    required this.createdAt,
    this.movieIds = const [],
    this.movieData = const [],
  });

  WatchlistFolder copyWith({
    String? name,
    String? emoji,
    List<String>? movieIds,
    List<String>? movieData,
  }) =>
      WatchlistFolder(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        createdAt: createdAt,
        movieIds: movieIds ?? List.from(this.movieIds),
        movieData: movieData ?? List.from(this.movieData),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'createdAt': createdAt.toIso8601String(),
        'movieIds': movieIds,
        'movieData': movieData,
      };

  factory WatchlistFolder.fromJson(Map<String, dynamic> json) =>
      WatchlistFolder(
        id: json['id'],
        name: json['name'],
        emoji: json['emoji'],
        createdAt: DateTime.parse(json['createdAt']),
        movieIds: List<String>.from(json['movieIds'] ?? []),
        movieData: List<String>.from(json['movieData'] ?? []),
      );
}

class WatchlistFolderProvider extends ChangeNotifier {
  List<WatchlistFolder> _folders = [];
  static const String _storageKey = 'watchlist_folders_data';

  final Databases _databases = Databases(client);
  String? _currentUserId;
  SyncProvider? _syncProvider;

  WatchlistFolderProvider([List<WatchlistFolder>? initial]) {
    if (initial != null && initial.isNotEmpty) {
      _folders = List.from(initial);
      _saveFolders(); 
    } else {
      _loadFolders();
    }
  }

  void clearData() {
    _folders.clear();
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) => prefs.remove(_storageKey));
  }

  void setUserId(String? userId) {
    _currentUserId = userId;
    if (userId != null) {
      // Always re-sync folders from cloud on login for cross-device support.
      syncFromAppwrite();
    } else {
      clearData();
    }
  }

  void setSyncProvider(SyncProvider syncProvider) {
    _syncProvider = syncProvider;
  }

  List<WatchlistFolder> get folders => List.unmodifiable(_folders);

  void addFolder(WatchlistFolder folder) {
    _folders.add(folder);
    notifyListeners();
    _saveFolders();
    if (_currentUserId != null) _syncFolderToAppwrite(folder);
  }

  void updateFolder(String id, {String? name, String? emoji}) {
    final idx = _folders.indexWhere((f) => f.id == id);
    if (idx == -1) return;
    _folders[idx] = _folders[idx].copyWith(name: name, emoji: emoji);
    notifyListeners();
    _saveFolders();
    if (_currentUserId != null) _syncFolderToAppwrite(_folders[idx]);
  }

  void deleteFolder(String id) {
    final folder = _folders.firstWhere((f) => f.id == id, orElse: () => _folders[0]);
    _folders.removeWhere((f) => f.id == id);
    notifyListeners();
    _saveFolders();
    if (_currentUserId != null) _triggerFolderDelete(folder);
  }

  void _triggerFolderDelete(WatchlistFolder folder) {
    if (_currentUserId == null || _syncProvider == null) return;

    _syncProvider!.addToQueue(
      userId: _currentUserId!,
      itemId: 0,
      mediaType: 'folder',
      actionType: SyncActionType.deleteFolder,
      payload: {
        AppwriteConstants.attrUserId: _currentUserId,
        AppwriteConstants.attrFolderName: folder.name,
      },
    );
  }

  void addToFolder({
    required String id,
    required String title,
    required String posterPath,
    required bool isMovie,
    required String folderId,
  }) {
    final idx = _folders.indexWhere((f) => f.id == folderId);
    if (idx == -1) return;
    if (!_folders[idx].movieIds.contains(id)) {
      final movieJson = json.encode({
        'id': id,
        'title': title,
        'posterPath': posterPath,
        'isMovie': isMovie,
      });

      _folders[idx] = _folders[idx].copyWith(
        movieIds: [..._folders[idx].movieIds, id],
        movieData: [..._folders[idx].movieData, movieJson],
      );
      notifyListeners();
      _saveFolders();
      if (_currentUserId != null) _syncFolderToAppwrite(_folders[idx]);
    }
  }

  void removeFromFolder(String movieId, String folderId) {
    final idx = _folders.indexWhere((f) => f.id == folderId);
    if (idx == -1) return;
    
    final newIds = _folders[idx].movieIds.where((id) => id != movieId).toList();
    final newData = _folders[idx].movieData.where((data) {
      final decoded = json.decode(data);
      return decoded['id'] != movieId;
    }).toList();

    _folders[idx] = _folders[idx].copyWith(
      movieIds: newIds,
      movieData: newData,
    );
    notifyListeners();
    _saveFolders();
    if (_currentUserId != null) _syncFolderToAppwrite(_folders[idx]);
  }

  // Appwrite Sync Logic (Refactored to use SyncProvider)
  void _syncFolderToAppwrite(WatchlistFolder folder) {
    if (_currentUserId == null || _syncProvider == null) return;

    final data = {
      'id': folder.id, // For routing in SyncProvider
      AppwriteConstants.attrUserId: _currentUserId,
      AppwriteConstants.attrFolderName: folder.name,
      AppwriteConstants.attrFolderEmoji: folder.emoji,
      AppwriteConstants.attrMovieIds: folder.movieIds,
      AppwriteConstants.attrMovieData: folder.movieData,
      AppwriteConstants.attrCreatedAt: folder.createdAt.toIso8601String(),
    };

    _syncProvider!.addToQueue(
      userId: _currentUserId!,
      itemId: 0, // Not used for folders, payload.id is used
      mediaType: 'folder',
      actionType: SyncActionType.updateFolder,
      payload: data,
    );
  }



  Future<void> syncFromAppwrite() async {
    if (_currentUserId == null) return;

    try {
      final response = await _databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.foldersCollectionId,
        queries: [Query.equal(AppwriteConstants.attrUserId, _currentUserId!)],
      );

      if (response.documents.isNotEmpty) {
        _folders = response.documents.map((doc) => WatchlistFolder(
          id: doc.$id.replaceFirst('${_currentUserId}_', ''),
          name: doc.data[AppwriteConstants.attrFolderName],
          emoji: doc.data[AppwriteConstants.attrFolderEmoji],
          createdAt: DateTime.tryParse(doc.data[AppwriteConstants.attrCreatedAt] ?? '') ?? DateTime.now(),
          movieIds: List<String>.from(doc.data[AppwriteConstants.attrMovieIds] ?? []),
          movieData: List<String>.from(doc.data[AppwriteConstants.attrMovieData] ?? []),
        )).toList();
        notifyListeners();
        _saveFolders();
      }
    } catch (e) {
      debugPrint('Appwrite Folders Load Error: $e');
    }
  }

  Future<void> _saveFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(_folders.map((f) => f.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  Future<void> _loadFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encoded = prefs.getString(_storageKey);
    if (encoded != null) {
      final List decoded = json.decode(encoded);
      _folders = decoded.map((item) => WatchlistFolder.fromJson(item)).toList();
      notifyListeners();
    } else {
      // Default folders if none saved
      _folders = [
        WatchlistFolder(
          id: 'f1',
          name: 'Must Watch',
          emoji: '🔥',
          createdAt: DateTime.now(),
        ),
        WatchlistFolder(
          id: 'f2',
          name: 'Date Night',
          emoji: '💑',
          createdAt: DateTime.now(),
        ),
      ];
      _saveFolders();
      notifyListeners();
    }
  }
}
