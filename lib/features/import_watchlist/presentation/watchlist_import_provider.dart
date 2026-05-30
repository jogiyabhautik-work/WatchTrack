import 'package:flutter/foundation.dart';
import 'package:watch_track/features/import_watchlist/domain/import_matcher.dart';
import 'package:watch_track/features/import_watchlist/services/file_import_service.dart';
import 'package:watch_track/core/providers/tracking_provider.dart';
import 'package:watch_track/core/providers/watchlist_folder_provider.dart';
import 'package:watch_track/data/models/user_title_model.dart';
import 'package:watch_track/features/import_watchlist/domain/smart_import_parser.dart';

enum ImportState { idle, readingFile, searchingTMDB, reviewing, done, error }

class WatchlistImportProvider extends ChangeNotifier {
  final ImportMatcher _matcher;
  final TrackingProvider _trackingProvider;
  final WatchlistFolderProvider _folderProvider;

  WatchlistImportProvider(this._matcher, this._trackingProvider, this._folderProvider);

  ImportState _state = ImportState.idle;
  ImportState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String _fileName = '';
  String get fileName => _fileName;

  List<MatchResult> _results = [];
  List<MatchResult> get results => _results;

  int _totalItems = 0;
  int get totalItems => _totalItems;

  int _processedItems = 0;
  int get processedItems => _processedItems;

  void reset() {
    _state = ImportState.idle;
    _errorMessage = null;
    _fileName = '';
    _results = [];
    _totalItems = 0;
    _processedItems = 0;
    notifyListeners();
  }

  Future<void> startImportFromFile() async {
    reset();
    _state = ImportState.readingFile;
    notifyListeners();

    final fileResult = await FileImportService.pickAndParseFile();

    if (fileResult.error != null) {
      _errorMessage = fileResult.error;
      _state = ImportState.error;
      notifyListeners();
      return;
    }

    _fileName = fileResult.fileName;
    
    // Use SmartImportParser to filter out garbage from files as well
    final parsedTitles = SmartImportParser.parsePastedText(fileResult.rawTitles.join('\n'));
    if (parsedTitles.isEmpty) {
      _errorMessage = 'File is empty or contains no valid text.';
      _state = ImportState.error;
      notifyListeners();
      return;
    }

    await _processRawTitles(parsedTitles);
  }

  Future<void> startImportFromText(String text) async {
    reset();
    _state = ImportState.readingFile;
    if (text.trim().isEmpty) return;

    _state = ImportState.readingFile;
    _fileName = 'Pasted Text';
    notifyListeners();

    final titles = SmartImportParser.parsePastedText(text);

    if (titles.isEmpty) {
      _errorMessage = 'No valid titles found in text.';
      _state = ImportState.error;
      notifyListeners();
      return;
    }

    await _processRawTitles(titles);
  }

  Future<void> _processRawTitles(List<String> rawTitles) async {
    _totalItems = rawTitles.length;
    _state = ImportState.searchingTMDB;
    notifyListeners();

    _results = await _matcher.processTitles(
      rawTitles,
      (processed, total) {
        _processedItems = processed;
        notifyListeners();
      },
      isDuplicate: (tmdbId) => _trackingProvider.getTracking(int.parse(tmdbId)) != null,
    );

    _state = ImportState.reviewing;
    notifyListeners();
  }



  void toggleSelection(MatchResult result) {
    result.isSelected = !result.isSelected;
    notifyListeners();
  }

  void selectAll() {
    for (var r in _results) {
      if (r.matchedMovie != null) r.isSelected = true;
    }
    notifyListeners();
  }

  void deselectAll() {
    for (var r in _results) {
      r.isSelected = false;
    }
    notifyListeners();
  }

  Future<void> commitImport({String? targetFolderName}) async {
    final selectedItems = _results.where((r) => r.isSelected && r.matchedMovie != null).toList();

    for (var item in selectedItems) {
      final movie = item.matchedMovie!;
      
      // Save to TrackingProvider
      if (_trackingProvider.getTracking(int.parse(movie.id)) == null) {
         await _trackingProvider.updateStatus(movie, TrackingStatus.watchlist);
      }

      // Save to WatchlistFolderProvider if a target folder is specified
      if (targetFolderName != null && targetFolderName.isNotEmpty) {
         // Create folder if it doesn't exist
         if (!_folderProvider.folders.any((f) => f.name == targetFolderName)) {
           _folderProvider.addFolder(WatchlistFolder(
             id: DateTime.now().millisecondsSinceEpoch.toString(),
             name: targetFolderName,
             emoji: '📁',
             createdAt: DateTime.now(),
           ));
         }
         
         // Add to folder
         final folder = _folderProvider.folders.firstWhere((f) => f.name == targetFolderName);
         if (!folder.movieIds.contains(movie.id)) {
           _folderProvider.addToFolder(
             id: movie.id,
             title: movie.title,
             posterPath: movie.posterPath,
             isMovie: movie.isMovie,
             folderId: folder.id,
           );
         }
      }
    }

    _state = ImportState.done;
    notifyListeners();
  }
}
