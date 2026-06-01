import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:watch_track/core/services/global_youtube_service.dart';
import 'package:watch_track/features/soundtrack/domain/models/song_model.dart';
import 'package:watch_track/features/soundtrack/domain/enums/song_source.dart';

class AudioPlayerProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
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
  SongModel? get currentSong => _currentIndex >= 0 && _currentIndex < _queue.length ? _queue[_currentIndex] : null;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  bool get isShuffle => _isShuffle;
  bool get isRepeat => _isRepeat;
  int get repeatMode => _repeatMode;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  int get sleepTimerMinutes => _sleepTimerMinutes;

  AudioPlayerProvider() {
    _initAudioPlayerListeners();
  }

  void _initAudioPlayerListeners() {
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isBuffering = state.processingState == ProcessingState.buffering || state.processingState == ProcessingState.loading;
      notifyListeners();

      if (state.processingState == ProcessingState.completed) {
        next();
      }
    });

    _audioPlayer.positionStream.listen((position) {
      _currentPosition = position;
      notifyListeners();
    });

    _audioPlayer.durationStream.listen((duration) {
      _totalDuration = duration ?? Duration.zero;
      notifyListeners();
    });
  }

  Future<void> playSong(SongModel song, {List<SongModel>? queue, Duration? startPosition}) async {
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
    await _startPlayback(song, startPosition: startPosition);
  }

  Future<void> _startPlayback(SongModel song, {Duration? startPosition}) async {
    _isPlaying = false;
    _isBuffering = true;
    _currentPosition = startPosition ?? Duration.zero;
    _totalDuration = Duration.zero;
    notifyListeners();

    try {
      String? audioUrl = song.externalUrl;
      
      if (song.source == SongSource.youtube && song.id.isNotEmpty) {
        audioUrl = await GlobalYouTubeService().getAudioStreamUrl(song.id);
      }

      if (audioUrl != null) {
        AudioSource audioSource;

        if (song.source == SongSource.youtube) {
          // Use LockCachingAudioSource which uses Dart's HTTP client internally to cache and stream, bypassing ExoPlayer blocks
          audioSource = LockCachingAudioSource(
            Uri.parse(audioUrl),
            headers: const {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            },
            tag: MediaItem(
              id: song.id,
              album: song.artist,
              title: song.title,
              artUri: song.thumbnailUrl != null ? Uri.parse(song.thumbnailUrl!) : null,
            ),
          );
        } else {
          audioSource = AudioSource.uri(
            Uri.parse(audioUrl),
            tag: MediaItem(
              id: song.id,
              album: song.artist,
              title: song.title,
              artUri: song.thumbnailUrl != null ? Uri.parse(song.thumbnailUrl!) : null,
            ),
          );
        }
        
        await _audioPlayer.setAudioSource(audioSource, initialPosition: startPosition);
        await _audioPlayer.play();
      } else {
        debugPrint('Could not find audio stream for ${song.title}');
        _isBuffering = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error starting playback: $e');
      _isBuffering = false;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    await _audioPlayer.play();
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void toggleRepeat() {
    _repeatMode = (_repeatMode + 1) % 3;
    _isRepeat = _repeatMode > 0;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
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
  void addSongToQueue(SongModel song) {
    if (!_queue.any((s) => s.id == song.id)) {
      _queue.add(song);
      notifyListeners();
    }
  }

  void removeSongFromQueue(SongModel song) {
    final index = _queue.indexWhere((s) => s.id == song.id);
    if (index != -1) {
      _queue.removeAt(index);
      if (_currentIndex == index) {
        if (_queue.isEmpty) {
          closePlayer();
        } else {
          _currentIndex = _currentIndex % _queue.length;
          _startPlayback(_queue[_currentIndex]);
        }
      } else if (_currentIndex > index) {
        _currentIndex--;
      }
      notifyListeners();
    }
  }

  void clearQueue() {
    _queue.clear();
    closePlayer();
  }

  void shuffleQueue() {
    if (_queue.length > 1) {
      final current = currentSong;
      _queue.shuffle();
      if (current != null) {
        _currentIndex = _queue.indexOf(current);
      }
      notifyListeners();
    }
  }

  void playSongAtIndex(int index) {
    if (index >= 0 && index < _queue.length) {
      _currentIndex = index;
      _startPlayback(_queue[_currentIndex]);
    }
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    
    if (_repeatMode == 1) {
      await _startPlayback(_queue[_currentIndex]);
      return;
    }

    if (_isShuffle) {
      final random = Random();
      int nextIndex;
      if (_queue.length > 1) {
        do {
          nextIndex = random.nextInt(_queue.length);
        } while (nextIndex == _currentIndex);
      } else {
        nextIndex = 0;
      }
      _currentIndex = nextIndex;
      await _startPlayback(_queue[_currentIndex]);
      return;
    }

    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      await _startPlayback(_queue[_currentIndex]);
    } else {
      if (_repeatMode == 2) {
        _currentIndex = 0;
        await _startPlayback(_queue[_currentIndex]);
      } else {
        await _audioPlayer.stop();
        _isPlaying = false;
        _isBuffering = false;
        notifyListeners();
      }
    }
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (_currentPosition.inSeconds > 3) {
      await seek(Duration.zero);
    } else if (_isShuffle) {
      final random = Random();
      int nextIndex;
      if (_queue.length > 1) {
        do {
          nextIndex = random.nextInt(_queue.length);
        } while (nextIndex == _currentIndex);
      } else {
        nextIndex = 0;
      }
      _currentIndex = nextIndex;
      await _startPlayback(_queue[_currentIndex]);
    } else if (_currentIndex > 0) {
      _currentIndex--;
      await _startPlayback(_queue[_currentIndex]);
    } else {
      if (_repeatMode == 2) {
        _currentIndex = _queue.length - 1;
        await _startPlayback(_queue[_currentIndex]);
      }
    }
  }

  void closePlayer() {
    _audioPlayer.stop();
    _sleepTimer?.cancel();
    _sleepTimerMinutes = 0;
    _queue = [];
    _currentIndex = -1;
    _isPlaying = false;
    _isBuffering = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}
