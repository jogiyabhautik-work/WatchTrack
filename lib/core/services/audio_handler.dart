 import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

class SoundtrackAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: []);

  SoundtrackAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    await _player.setAudioSource(_playlist);

    // Broadcast playback state changes to the OS
    _player.playbackEventStream.listen(_broadcastState);

    // Broadcast current media item metadata to the OS
    _player.currentIndexStream.listen((index) {
      if (index != null && queue.value.isNotEmpty && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
      }
    });

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        if (_player.loopMode == LoopMode.off && _player.currentIndex == queue.value.length - 1) {
          // Playlist ended, we could stop or just pause
          pause();
        }
      }
    });
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  // Define how the handler responds to the UI/OS actions

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _player.setLoopMode(LoopMode.all);
        break;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    if (shuffleMode == AudioServiceShuffleMode.none) {
      await _player.setShuffleModeEnabled(false);
    } else {
      await _player.shuffle();
      await _player.setShuffleModeEnabled(true);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < queue.value.length) {
      await _player.seek(Duration.zero, index: index);
    }
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'loadPlaylist' && extras != null) {
      final itemsMap = extras['items'] as List;
      final urisMap = extras['uris'] as List;
      final initialIndex = extras['initialIndex'] as int;
      
      final items = itemsMap.map((m) => MediaItem(
        id: m['id'],
        album: m['album'],
        title: m['title'],
        artist: m['artist'],
        artUri: m['artUri'] != null ? Uri.parse(m['artUri']) : null,
        duration: m['duration'] != null ? Duration(milliseconds: m['duration']) : null,
      )).toList();
      
      final uris = urisMap.map((u) => Uri.parse(u)).toList();
      
      await loadPlaylist(items, uris, initialIndex: initialIndex);
    } else if (name == 'clearQueue') {
      await clearQueue();
    }
  }

  // Custom methods for queue management from the provider

  Future<void> loadPlaylist(List<MediaItem> items, List<Uri> audioUris, {int initialIndex = 0}) async {
    // Clear the current queue
    final currentQueue = queue.value;
    if (currentQueue.isNotEmpty) {
      await _playlist.clear();
      queue.add([]);
    }

    final audioSources = <AudioSource>[];
    for (int i = 0; i < items.length; i++) {
      audioSources.add(
        AudioSource.uri(
          audioUris[i],
          tag: items[i],
          headers: const {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
      );
    }

    await _playlist.addAll(audioSources);
    queue.add(items);
    
    if (initialIndex < items.length) {
      await _player.seek(Duration.zero, index: initialIndex);
    }
  }

  Future<void> addToQueue(MediaItem item, Uri audioUri) async {
    await _playlist.add(
      AudioSource.uri(
        audioUri,
        tag: item,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ),
    );
    final newQueue = queue.value..add(item);
    queue.add(newQueue);
  }

  Future<void> clearQueue() async {
    await stop();
    await _playlist.clear();
    queue.add([]);
  }

  // Expose player streams for the UI provider to listen to
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<SequenceState?> get sequenceStateStream => _player.sequenceStateStream;
}
