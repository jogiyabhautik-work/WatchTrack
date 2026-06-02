import 'package:flutter/foundation.dart';

import '../services/lyrics_service.dart';
import 'synced_lyrics_model.dart';

enum LyricsStatus { idle, loading, loaded, error, notFound }

class LyricsState {
  final LyricsStatus status;
  final SyncedLyrics? lyrics;
  final String? errorMessage;
  final String? currentArtist;
  final String? currentTitle;

  const LyricsState({
    this.status = LyricsStatus.idle,
    this.lyrics,
    this.errorMessage,
    this.currentArtist,
    this.currentTitle,
  });

  LyricsState copyWith({
    LyricsStatus? status,
    SyncedLyrics? lyrics,
    String? errorMessage,
    String? currentArtist,
    String? currentTitle,
  }) {
    return LyricsState(
      status: status ?? this.status,
      lyrics: lyrics ?? this.lyrics,
      errorMessage: errorMessage ?? this.errorMessage,
      currentArtist: currentArtist ?? this.currentArtist,
      currentTitle: currentTitle ?? this.currentTitle,
    );
  }

  bool get hasLyrics => lyrics != null && lyrics!.lines.isNotEmpty;
  bool get isSynced => lyrics?.isSynced ?? false;
}

class LyricsProvider extends ChangeNotifier {
  LyricsState _state = const LyricsState();
  int _requestId = 0;

  LyricsState get state => _state;
  LyricsStatus get status => _state.status;
  SyncedLyrics? get lyrics => _state.lyrics;
  bool get hasLyrics => _state.hasLyrics;
  bool get isSynced => _state.isSynced;

  Future<void> loadLyrics(
    String artist,
    String title, {
    Duration? duration,
  }) async {
    if (_state.currentArtist == artist &&
        _state.currentTitle == title &&
        _state.status == LyricsStatus.loaded) {
      return;
    }

    final requestId = ++_requestId;
    _state = LyricsState(
      status: LyricsStatus.loading,
      currentArtist: artist,
      currentTitle: title,
    );
    notifyListeners();

    try {
      final result = await LyricsService.fetchSyncedLyrics(
        artist,
        title,
        duration: duration,
      );

      if (requestId != _requestId) return;

      if (result != null && result.lines.isNotEmpty) {
        _state = _state.copyWith(status: LyricsStatus.loaded, lyrics: result);
      } else {
        _state = _state.copyWith(status: LyricsStatus.notFound);
      }
    } catch (e) {
      if (requestId != _requestId) return;
      _state = _state.copyWith(
        status: LyricsStatus.error,
        errorMessage: e.toString(),
      );
    }

    notifyListeners();
  }

  void clear() {
    _requestId++;
    _state = const LyricsState();
    notifyListeners();
  }

  int currentLineIndex(Duration position) {
    if (!_state.hasLyrics) return -1;
    return _state.lyrics!.currentLineIndex(position);
  }
}
