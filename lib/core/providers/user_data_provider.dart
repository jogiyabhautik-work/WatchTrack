// ignore_for_file: deprecated_member_use, avoid_print, unused_element, experimental_member_use
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:appwrite/appwrite.dart';
import 'package:watch_track/core/appwrite_client.dart';
import 'package:watch_track/core/appwrite_constants.dart';
import 'package:watch_track/features/soundtrack/domain/models/song_model.dart';

class UserDataProvider extends ChangeNotifier {
  Set<String> _favoriteGenres = {};
  Set<String> _favoriteActors = {};
  List<SongModel> _favoriteSongs = [];
  String? _pfpUrl;
  bool _onboardingDone = false;

  final Databases _databases = Databases(client);
  String? _currentUserId;

  static const String _genresKey = 'user_favorite_genres';
  static const String _actorsKey = 'user_favorite_actors';
  static const String _pfpKey = 'user_pfp';
  static const String _onboardingKey = 'user_onboarding_done';
  static const String _songsKey = 'user_favorite_songs';

  UserDataProvider() {
    _loadData();
  }

  void clearData() {
    _favoriteGenres.clear();
    _favoriteActors.clear();
    _favoriteSongs.clear();
    _pfpUrl = null;
    _onboardingDone = false;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_genresKey);
      prefs.remove(_actorsKey);
      prefs.remove(_pfpKey);
      prefs.remove(_onboardingKey);
      prefs.remove(_songsKey);
    });
  }

  void setUserId(String? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      if (userId != null) {
        syncFromAppwrite();
      } else {
        clearData();
      }
    }
  }

  Set<String> get favoriteGenres => _favoriteGenres;
  Set<String> get favoriteActors => _favoriteActors;
  List<SongModel> get favoriteSongs => _favoriteSongs;
  String? get pfpUrl => _pfpUrl;
  bool get onboardingDone => _onboardingDone;

  void updatePfp(String url) {
    _pfpUrl = url;
    notifyListeners();
    _saveData();
    if (_currentUserId != null) _syncPrefsToAppwrite();
  }

  void toggleFavoriteGenre(String genre) {
    if (_favoriteGenres.contains(genre)) {
      _favoriteGenres.remove(genre);
    } else {
      _favoriteGenres.add(genre);
    }
    notifyListeners();
    _saveData();
    if (_currentUserId != null) _syncPrefsToAppwrite();
  }

  void toggleFavoriteSong(SongModel song) {
    final exists = _favoriteSongs.any((s) => s.id == song.id);
    if (exists) {
      _favoriteSongs.removeWhere((s) => s.id == song.id);
    } else {
      _favoriteSongs.insert(0, song); // Add to top
    }
    notifyListeners();
    _saveData();
    if (_currentUserId != null) _syncPrefsToAppwrite();
  }

  void saveOnboardingGenres(Set<String> genres) {
    _favoriteGenres.addAll(genres);
    _onboardingDone = true;
    notifyListeners();
    _saveData();
    if (_currentUserId != null) _syncPrefsToAppwrite();
  }

  void saveOnboardingActors(Set<String> actors) {
    _favoriteActors.addAll(actors);
    notifyListeners();
    _saveData();
    if (_currentUserId != null) _syncPrefsToAppwrite();
  }

  // Appwrite Sync Logic
  Future<void> _syncPrefsToAppwrite() async {
    if (_currentUserId == null) return;

    final data = {
      AppwriteConstants.attrUserId: _currentUserId,
      AppwriteConstants.attrFavoriteGenres: _favoriteGenres.toList(),
      AppwriteConstants.attrFavoriteActors: _favoriteActors.toList(),
      AppwriteConstants.attrFavoriteSongs: _favoriteSongs.map((s) => jsonEncode(s.toJson())).toList(),
      AppwriteConstants.attrOnboardingDone: _onboardingDone,
      AppwriteConstants.attrPfpUrl: _pfpUrl,
    };

    try {
      try {
        await _databases.updateDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.userPrefsCollectionId,
          documentId: _currentUserId!,
          data: data,
        );
      } on AppwriteException catch (e) {
        if (e.code == 404) {
          await _databases.createDocument(
            databaseId: AppwriteConstants.databaseId,
            collectionId: AppwriteConstants.userPrefsCollectionId,
            documentId: _currentUserId!,
            data: data,
          );
        } else {
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('Appwrite Prefs Sync Error: $e');
    }
  }

  Future<void> syncFromAppwrite() async {
    if (_currentUserId == null) return;

    try {
      final doc = await _databases.getDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.userPrefsCollectionId,
        documentId: _currentUserId!,
      );
      _favoriteGenres = (doc.data[AppwriteConstants.attrFavoriteGenres] as List?)?.map((e) => e.toString()).toSet() ?? {};
      _favoriteActors = (doc.data[AppwriteConstants.attrFavoriteActors] as List?)?.map((e) => e.toString()).toSet() ?? {};
      
      final songsList = doc.data[AppwriteConstants.attrFavoriteSongs] as List?;
      if (songsList != null) {
        _favoriteSongs = songsList.map((e) => SongModel.fromJson(jsonDecode(e.toString()))).toList();
      } else {
        _favoriteSongs = [];
      }
      
      _pfpUrl = doc.data[AppwriteConstants.attrPfpUrl]?.toString();
      _onboardingDone = doc.data[AppwriteConstants.attrOnboardingDone] ?? false;

      notifyListeners();
      _saveData();
    } catch (e) {
      debugPrint('Appwrite User Data Load Error: $e');
    }
  }

  void _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(_genresKey, _favoriteGenres.toList());
    prefs.setStringList(_actorsKey, _favoriteActors.toList());
    prefs.setStringList(_songsKey, _favoriteSongs.map((s) => jsonEncode(s.toJson())).toList());
    prefs.setBool(_onboardingKey, _onboardingDone);
    if (_pfpUrl != null) prefs.setString(_pfpKey, _pfpUrl!);
  }

  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    _favoriteGenres = prefs.getStringList(_genresKey)?.toSet() ?? {};
    _favoriteActors = prefs.getStringList(_actorsKey)?.toSet() ?? {};
    
    final savedSongs = prefs.getStringList(_songsKey);
    if (savedSongs != null) {
      _favoriteSongs = savedSongs.map((s) => SongModel.fromJson(jsonDecode(s))).toList();
    } else {
      _favoriteSongs = [];
    }
    
    _pfpUrl = prefs.getString(_pfpKey);
    _onboardingDone = prefs.getBool(_onboardingKey) ?? false;

    notifyListeners();
  }
}

