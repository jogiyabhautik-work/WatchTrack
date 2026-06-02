import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:text_scroll/text_scroll.dart';

import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/core/providers/audio_player_provider.dart';
import 'package:watch_track/core/providers/lyrics_provider.dart';
import 'package:watch_track/core/providers/user_data_provider.dart';
import 'package:watch_track/features/soundtrack/domain/models/song_model.dart';
import 'package:watch_track/presentation/screens/audio/youtube_video_screen.dart';
import 'package:watch_track/presentation/widgets/synced_lyrics_view.dart';

class FullScreenAudioPlayer extends StatefulWidget {
  const FullScreenAudioPlayer({super.key});

  @override
  State<FullScreenAudioPlayer> createState() => _FullScreenAudioPlayerState();
}

class _FullScreenAudioPlayerState extends State<FullScreenAudioPlayer> {
  String? _lyricsSongId;

  bool _waitingForDuration = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final audioProvider = context.watch<AudioPlayerProvider>();
    final song = audioProvider.currentSong;
    if (song == null) return;

    final hasDuration = audioProvider.totalDuration != Duration.zero;

    if (song.id == _lyricsSongId) {
      if (_waitingForDuration && hasDuration) {
        _waitingForDuration = false;
      } else {
        return;
      }
    } else {
      _lyricsSongId = song.id;
      _waitingForDuration = !hasDuration;
      if (_waitingForDuration) return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LyricsProvider>().loadLyrics(
        song.artist,
        song.title,
        duration: audioProvider.totalDuration,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final song = context.select<AudioPlayerProvider, SongModel?>(
      (p) => p.currentSong,
    );

    if (song == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _BlurredBackground(song: song),
          SafeArea(
            child: Column(
              children: [
                const _TopBar(),
                const Spacer(flex: 1),
                _AnimatedArtwork(song: song),
                const Spacer(flex: 1),
                _SongInfo(song: song),
                const SizedBox(height: 24),
                const _ProgressBar(),
                const SizedBox(height: 16),
                const _MainControls(),
                const SizedBox(height: 24),
                const _BottomActions(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurredBackground extends StatelessWidget {
  final SongModel song;
  const _BlurredBackground({required this.song});

  String _getSafeThumbnailUrl(String videoId) {
    return 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final safeThumbnail = _getSafeThumbnailUrl(song.id);
    return Stack(
      children: [
        Positioned.fill(
          child: CachedNetworkImage(
            imageUrl: safeThumbnail,
            fit: BoxFit.cover,
            errorWidget: (_, error, stackTrace) => Container(color: AppColors.surface),
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black.withValues(alpha: 0.95),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  void _showSleepTimerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return const _SleepTimerSheet();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sleepTimerMinutes = context.select<AudioPlayerProvider, int>(
      (p) => p.sleepTimerMinutes,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 36,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            'NOW PLAYING',
            style: GoogleFonts.dmSans(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: sleepTimerMinutes > 0
                      ? AppColors.primary
                      : Colors.white,
                  size: 28,
                ),
                if (sleepTimerMinutes > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        sleepTimerMinutes.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => _showSleepTimerDialog(context),
          ),
        ],
      ),
    );
  }
}

class _SleepTimerSheet extends StatelessWidget {
  const _SleepTimerSheet();

  @override
  Widget build(BuildContext context) {
    final currentMinutes = context.select<AudioPlayerProvider, int>(
      (p) => p.sleepTimerMinutes,
    );
    final options = [0, 15, 30, 45, 60];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sleep Timer',
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...options.map((mins) {
            final isSelected = currentMinutes == mins;
            return ListTile(
              title: Text(
                mins == 0 ? 'Off' : '$mins Minutes',
                style: GoogleFonts.dmSans(
                  color: isSelected ? AppColors.primary : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle, color: AppColors.primary)
                  : null,
              onTap: () {
                context.read<AudioPlayerProvider>().setSleepTimer(mins);
                Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    );
  }
}

class _AnimatedArtwork extends StatelessWidget {
  final SongModel song;
  const _AnimatedArtwork({required this.song});

  String _getSafeThumbnailUrl(String videoId) {
    return 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final safeThumbnail = _getSafeThumbnailUrl(song.id);
    final isPlaying = context.select<AudioPlayerProvider, bool>(
      (p) => p.isPlaying,
    );

    return AnimatedScale(
      scale: isPlaying ? 1.0 : 0.85,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      child: Hero(
        tag: 'audio_artwork_${song.id}',
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.width * 0.85,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 40,
                offset: const Offset(0, 20),
                spreadRadius: isPlaying ? 5 : 0,
              )
            ],
            image: DecorationImage(
              image: CachedNetworkImageProvider(safeThumbnail),
              fit: BoxFit.cover,
              onError: (_, error) => const AssetImage('assets/images/placeholder.png'),
            ),
          ),
        ),
      ),
    );
  }
}

class _SongInfo extends StatelessWidget {
  final SongModel song;
  const _SongInfo({required this.song});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextScroll(
                  song.title,
                  mode: TextScrollMode.bouncing,
                  velocity: const Velocity(pixelsPerSecond: Offset(30, 0)),
                  delayBefore: const Duration(seconds: 2),
                  pauseBetween: const Duration(seconds: 3),
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  selectable: true,
                ),
                const SizedBox(height: 8),
                TextScroll(
                  song.artist,
                  mode: TextScrollMode.bouncing,
                  velocity: const Velocity(pixelsPerSecond: Offset(20, 0)),
                  delayBefore: const Duration(seconds: 3),
                  pauseBetween: const Duration(seconds: 4),
                  style: GoogleFonts.dmSans(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  selectable: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Consumer<UserDataProvider>(
            builder: (context, userData, _) {
              final isFav = userData.favoriteSongs.any((s) => s.id == song.id);
              return IconButton(
                icon: Icon(
                  isFav
                      ? Icons.favorite_rounded
                      : Icons.favorite_outline_rounded,
                  size: 32,
                ),
                color: isFav ? AppColors.primary : Colors.white70,
                onPressed: () {
                  userData.toggleFavoriteSong(song);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar();

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final currentPosition = context.select<AudioPlayerProvider, Duration>(
      (p) => p.currentPosition,
    );
    final totalDuration = context.select<AudioPlayerProvider, Duration>(
      (p) => p.totalDuration,
    );

    final maxVal = totalDuration.inMilliseconds.toDouble() > 0
        ? totalDuration.inMilliseconds.toDouble()
        : 1.0;
    final currentVal = currentPosition.inMilliseconds.toDouble().clamp(
      0.0,
      maxVal,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.2),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              min: 0,
              max: maxVal,
              value: currentVal,
              onChanged: (val) {
                context.read<AudioPlayerProvider>().seek(
                  Duration(milliseconds: val.toInt()),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(currentPosition),
                  style: GoogleFonts.dmMono(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _formatDuration(totalDuration),
                  style: GoogleFonts.dmMono(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MainControls extends StatelessWidget {
  const _MainControls();

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerProvider>(
      builder: (context, audioProvider, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.shuffle_rounded),
                color: audioProvider.isShuffle
                    ? AppColors.primary
                    : Colors.white54,
                iconSize: 28,
                onPressed: () => audioProvider.toggleShuffle(),
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded),
                color: Colors.white,
                iconSize: 42,
                onPressed: () => audioProvider.previous(),
              ),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: IconButton(
                  icon: audioProvider.isBuffering
                      ? const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Icon(
                            audioProvider.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            key: ValueKey(audioProvider.isPlaying),
                          ),
                        ),
                  color: Colors.white,
                  iconSize: 48,
                  padding: const EdgeInsets.all(18),
                  onPressed: audioProvider.isBuffering
                      ? null
                      : () {
                          audioProvider.togglePlayPause();
                        },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded),
                color: Colors.white,
                iconSize: 42,
                onPressed: () => audioProvider.next(),
              ),
              IconButton(
                icon: Icon(
                  audioProvider.repeatMode == 2
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                ),
                color: audioProvider.repeatMode > 0
                    ? AppColors.primary
                    : Colors.white54,
                iconSize: 28,
                onPressed: () => audioProvider.toggleRepeat(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions();

  void _showQueueSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const _QueueSheet();
      },
    );
  }

  void _showLyricsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const _LyricsSheet();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final song = context.select<AudioPlayerProvider, SongModel?>(
      (p) => p.currentSong,
    );
    final hasVideo = song != null && song.availableModes.contains('video');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.queue_music_rounded),
            color: Colors.white70,
            iconSize: 28,
            onPressed: () => _showQueueSheet(context),
            tooltip: 'Queue',
          ),
          if (hasVideo)
            IconButton(
              icon: const Icon(Icons.videocam_rounded),
              color: Colors.white70,
              iconSize: 28,
              onPressed: () {
                final audioProvider = context.read<AudioPlayerProvider>();
                final currentPos = audioProvider.currentPosition;
                audioProvider.pause();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => YouTubeVideoScreen(
                      song: song,
                      startPosition: currentPos,
                    ),
                  ),
                );
              },
              tooltip: 'Switch to Video Mode',
            ),
          IconButton(
            icon: const Icon(Icons.lyrics_outlined),
            color: Colors.white70,
            iconSize: 28,
            onPressed: () => _showLyricsSheet(context),
            tooltip: 'Lyrics',
          ),
        ],
      ),
    );
  }
}

class _QueueSheet extends StatelessWidget {
  const _QueueSheet();

  String _getSafeThumbnailUrl(String videoId) {
    return 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.watch<AudioPlayerProvider>();
    final queue = audioProvider.queue;
    final currentSong = audioProvider.currentSong;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Up Next',
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final song = queue[index];
                final isPlaying = currentSong?.id == song.id;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: _getSafeThumbnailUrl(song.id),
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorWidget: (_, error, stackTrace) => Container(color: Colors.grey[800], width: 50, height: 50),
                    ),
                  ),
                  title: Text(
                    song.title,
                    style: GoogleFonts.dmSans(
                      color: isPlaying ? AppColors.primary : Colors.white,
                      fontWeight: isPlaying
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    song.artist,
                    style: GoogleFonts.dmSans(color: Colors.white54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: isPlaying
                      ? const Icon(
                          Icons.equalizer_rounded,
                          color: AppColors.primary,
                        )
                      : IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white38,
                          ),
                          onPressed: () {
                            audioProvider.removeSongFromQueue(song);
                          },
                        ),
                  onTap: () {
                    audioProvider.playSongAtIndex(index);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LyricsSheet extends StatelessWidget {
  const _LyricsSheet();

  void _loadLyrics(BuildContext context) {
    final song = context.read<AudioPlayerProvider>().currentSong;
    if (song == null) return;

    final audioProvider = context.read<AudioPlayerProvider>();
    context.read<LyricsProvider>().loadLyrics(
      song.artist,
      song.title,
      duration: audioProvider.totalDuration == Duration.zero
          ? null
          : audioProvider.totalDuration,
    );
  }

  @override
  Widget build(BuildContext context) {
    final song = context.select<AudioPlayerProvider, SongModel?>(
      (p) => p.currentSong,
    );
    final currentPosition = context.select<AudioPlayerProvider, Duration>(
      (p) => p.currentPosition,
    );
    final lyricsStatus = context.select<LyricsProvider, LyricsStatus>(
      (p) => p.status,
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                const Icon(
                  Icons.music_note_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song?.title ?? 'Lyrics',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        song?.artist ?? '',
                        style: GoogleFonts.dmSans(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white60,
                  ),
                  onPressed: song == null ? null : () => _loadLyrics(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.borderDefault, height: 1),
          Expanded(
            child: lyricsStatus == LyricsStatus.idle && song != null
                ? _LyricsLoader(onLoad: () => _loadLyrics(context))
                : SyncedLyricsView(
                    position: currentPosition,
                    onSeek: (timestamp) {
                      context.read<AudioPlayerProvider>().seek(timestamp);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LyricsLoader extends StatefulWidget {
  final VoidCallback onLoad;

  const _LyricsLoader({required this.onLoad});

  @override
  State<_LyricsLoader> createState() => _LyricsLoaderState();
}

class _LyricsLoaderState extends State<_LyricsLoader> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLoad();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }
}
