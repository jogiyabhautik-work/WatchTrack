import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watch_track/data/models/movie_model.dart';

class WatchlistProvider extends ChangeNotifier {
  List<Movie> _watchlist = [];
  static const String _storageKey = 'watchlist_data';

  WatchlistProvider() {
    _loadWatchlist();
  }

  List<Movie> get watchlist => _watchlist;

  bool isInWatchlist(String id) {
    return _watchlist.any((movie) => movie.id == id);
  }

  void toggleWatchlist(Movie movie) async {
    final index = _watchlist.indexWhere((m) => m.id == movie.id);
    if (index >= 0) {
      _watchlist.removeAt(index);
    } else {
      _watchlist.add(movie);
    }
    notifyListeners();
    _saveWatchlist();
  }

  void _saveWatchlist() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = json.encode(
      _watchlist.map((movie) => movie.toJson()).toList(),
    );
    await prefs.setString(_storageKey, encodedData);
  }

  void _loadWatchlist() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_storageKey);
    if (encodedData != null) {
      final List<dynamic> decodedData = json.decode(encodedData);
      _watchlist = decodedData.map((item) => Movie.fromJson(item, isMovie: item['isMovie'] ?? true)).toList();
      notifyListeners();
    }
  }
}
