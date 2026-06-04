import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:watch_track/core/services/global_youtube_service.dart';
import 'package:watch_track/features/soundtrack/domain/models/song_model.dart';
import 'package:watch_track/features/soundtrack/domain/enums/song_source.dart';
import 'package:watch_track/features/soundtrack/domain/enums/song_type.dart';
import 'package:watch_track/main.dart'; // To access global audioHandler

class AudioPlayerProvider extends ChangeNotifier {
  List<SongModel> _queue = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isShuffle = false;
  bool _isRepeat = false;
  int _repeatMode = 0; // 0 = off, 1 = repeat one, 2 = repeat all
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  // Sleep Timer state
  int _sleepTimerMinutes = 0;
  Timer? _sleepTimer;

  List<SongModel> get queue => _queue;
  SongModel? get currentSong =>
      _currentIndex >= 0 && _currentIndex < _queue.length
      ? _queue[_currentIndex]
      : null;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  bool get isShuffle => _isShuffle;
  bool get isRepeat => _isRepeat;
  int get repeatMode => _repeatMode;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  int get sleepTimerMinutes => _sleepTimerMinutes;

  AudioPlayerProvider() {
    _initAudioHandlerListeners();
  }

  void _initAudioHandlerListeners() {
    // Listen to playback state (playing, buffering, position)
    audioHandler.playbackState.listen((state) {
      _isPlaying = state.playing;
      _isBuffering = state.processingState == AudioProcessingState.loading || 
                     state.processingState == AudioProcessingState.buffering;
      
      notifyListeners();
    });

    // We can't directly listen to position from AudioService nicely without a stream, 
    // but the handler exposes it if we cast it, or we rely on periodic updates.
    // AudioService provides AudioService.position which is a stream:
    AudioService.position.listen((position) {
      _currentPosition = position;
      notifyListeners();
    });

    // Listen to media item changes (duration, current track)
    audioHandler.mediaItem.listen((item) {
      if (item != null) {
        _totalDuration = item.duration ?? Duration.zero;
        
        // Find which song in our queue matches this id
        final index = _queue.indexWhere((s) => s.id == item.id);
        if (index != -1) {
          _currentIndex = index;
        }
        notifyListeners();
      }
    });
  }

  Future<void> playSong(
    SongModel song, {
    List<SongModel>? queue,
    Duration? startPosition,
  }) async {
    if (queue != null) {
      _queue = List.from(queue);
    } else if (!_queue.any((s) => s.id == song.id)) {
      _queue = [song];
    }

    _currentIndex = _queue.indexWhere((s) => s.id == song.id);
    if (_currentIndex == -1) {
      _queue.add(song);
      _currentIndex = _queue.length - 1;
    }
    await _startPlayback(initialIndex: _currentIndex);
  }

  Future<void> _startPlayback({required int initialIndex}) async {
    _isPlaying = false;
    _isBuffering = true;
    notifyListeners();

    try {
      final items = <MediaItem>[];
      final audioUris = <Uri>[];

      for (var song in _queue) {
        String? audioUrl = song.externalUrl;

        if (song.source == SongSource.youtube && song.id.isNotEmpty) {
          audioUrl = await GlobalYouTubeService().getAudioStreamUrl(
            song.id,
            fallbackQuery: '${song.title} ${song.artist}'.trim(),
          );
        }

        if (audioUrl != null) {
          audioUris.add(Uri.parse(audioUrl));
          
          final artUri = song.thumbnailUrl != null && song.thumbnailUrl!.isNotEmpty
              ? Uri.parse(song.thumbnailUrl!)
              : (song.source == SongSource.youtube
                  ? Uri.parse('https://i.ytimg.com/vi/${song.id}/hqdefault.jpg')
                  : null);

          final albumName = song.type == SongType.unknown ? 'Track & Tube' : song.type.displayName;
          final durationObj = song.duration != null && song.duration!.isNotEmpty
              ? _parseDuration(song.duration!)
              : null;

          items.add(
            MediaItem(
              id: song.id,
              album: albumName,
              title: song.title,
              artist: song.artist,
              artUri: artUri,
              duration: durationObj,
            ),
          );
        }
      }

      if (items.isNotEmpty) {
        // Use custom command to load the queue into the handler
        await audioHandler.customAction('loadPlaylist', {
          'items': items.map((i) => {
            'id': i.id,
            'album': i.album,
            'title': i.title,
            'artist': i.artist,
            'artUri': i.artUri?.toString(),
            'duration': i.duration?.inMilliseconds,
          }).toList(),
          'uris': audioUris.map((u) => u.toString()).toList(),
          'initialIndex': initialIndex,
        });

        await audioHandler.play();
      } else {
        _isBuffering = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error starting playback: $e');
      _isBuffering = false;
      notifyListeners();
    }
  }

  Future<void> pause() async => await audioHandler.pause();
  Future<void> resume() async => await audioHandler.play();

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> toggleShuffle() async {
    _isShuffle = !_isShuffle;
    await audioHandler.setShuffleMode(
      _isShuffle ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    );
    notifyListeners();
  }

  Future<void> toggleRepeat() async {
    _repeatMode = (_repeatMode + 1) % 3;
    _isRepeat = _repeatMode > 0;
    
    AudioServiceRepeatMode mode;
    if (_repeatMode == 1) {
      mode = AudioServiceRepeatMode.one;
    } else if (_repeatMode == 2) {
      mode = AudioServiceRepeatMode.all;
    } else {
      mode = AudioServiceRepeatMode.none;
    }
    
    await audioHandler.setRepeatMode(mode);
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await audioHandler.seek(position);
  }

  void rewind10Seconds() {
    final newPos = _currentPosition - const Duration(seconds: 10);
    seek(newPos < Duration.zero ? Duration.zero : newPos);
  }

  void forward10Seconds() {
    final newPos = _currentPosition + const Duration(seconds: 10);
    seek(newPos > _totalDuration ? _totalDuration : newPos);
  }

  // Sleep Timer
  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    _sleepTimerMinutes = minutes;
    if (minutes > 0) {
      _sleepTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
        if (_sleepTimerMinutes > 0) {
          _sleepTimerMinutes--;
          if (_sleepTimerMinutes == 0) {
            _sleepTimer?.cancel();
            pause();
          }
          notifyListeners();
        } else {
          _sleepTimer?.cancel();
        }
      });
    }
    notifyListeners();
  }

  // Queue modification
  Future<void> addSongToQueue(SongModel song) async {
    if (!_queue.any((s) => s.id == song.id)) {
      _queue.add(song);
      // Not implemented dynamically appending to audio_handler queue for simplicity,
      // usually requires another custom action, but will work if we reload queue or implement it.
      notifyListeners();
    }
  }

  Future<void> removeSongFromQueue(SongModel song) async {
    final index = _queue.indexWhere((s) => s.id == song.id);
    if (index != -1) {
      _queue.removeAt(index);
      if (_currentIndex == index) {
        if (_queue.isEmpty) {
          await closePlayer();
        } else {
          _currentIndex = _currentIndex % _queue.length;
          await _startPlayback(initialIndex: _currentIndex);
        }
      } else if (_currentIndex > index) {
        _currentIndex--;
      }
      notifyListeners();
    }
  }

  Future<void> clearQueue() async {
    _queue.clear();
    await closePlayer();
  }

  void shuffleQueue() {
    if (_queue.length > 1) {
      final current = currentSong;
      _queue.shuffle();
      if (current != null) {
        _currentIndex = _queue.indexOf(current);
      }
      // Reload queue to handler
      _startPlayback(initialIndex: _currentIndex);
      notifyListeners();
    }
  }

  void playSongAtIndex(int index) {
    if (index >= 0 && index < _queue.length) {
      _currentIndex = index;
      // We can use skipToQueueItem if we implemented it, or seek.
      // AudioHandler seek allows jumping index if supported.
      // We'll just use a customAction or skip loop
      audioHandler.skipToQueueItem(index);
    }
  }

  Future<void> next() async => await audioHandler.skipToNext();
  Future<void> previous() async => await audioHandler.skipToPrevious();

  Future<void> closePlayer() async {
    await audioHandler.stop();
    await audioHandler.customAction('clearQueue');
    _sleepTimer?.cancel();
    _sleepTimerMinutes = 0;
    _queue = [];
    _currentIndex = -1;
    _isPlaying = false;
    _isBuffering = false;
    notifyListeners();
  }

  Duration? _parseDuration(String durationStr) {
    try {
      final parts = durationStr.split(':');
      if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        return Duration(minutes: minutes, seconds: seconds);
      } else if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final seconds = int.parse(parts[2]);
        return Duration(hours: hours, minutes: minutes, seconds: seconds);
      }
    } catch (e) {
      debugPrint('Error parsing duration: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    super.dispose();
  }
}
