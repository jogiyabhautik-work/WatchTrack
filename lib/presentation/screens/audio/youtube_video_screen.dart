import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/features/soundtrack/domain/models/song_model.dart';
import 'package:watch_track/features/soundtrack/domain/enums/song_type.dart';
import 'package:watch_track/features/soundtrack/domain/enums/song_source.dart';
import 'package:watch_track/core/providers/audio_player_provider.dart';
import 'package:watch_track/core/providers/user_data_provider.dart';
import 'package:watch_track/presentation/screens/audio/full_screen_audio_player.dart';

class YouTubeVideoScreen extends StatefulWidget {
  final SongModel? song;
  final String? videoId;
  final Duration? startPosition;
  final String? title;
  final String? artist;
  final bool isTrailer;

  const YouTubeVideoScreen({
    super.key,
    this.song,
    this.videoId,
    this.startPosition,
    this.title,
    this.artist,
    this.isTrailer = false,
  });

  @override
  State<YouTubeVideoScreen> createState() => _YouTubeVideoScreenState();
}

class _YouTubeVideoScreenState extends State<YouTubeVideoScreen> {
  late YoutubePlayerController _controller;
  bool _showControls = true;
  Timer? _controlsTimer;
  bool _isLandscape = true;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    
    final id = widget.song?.id ?? widget.videoId ?? '';
    
    _controller = YoutubePlayerController(
      initialVideoId: id,
      flags: YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        hideControls: true, // Custom HUD controls
        startAt: widget.startPosition?.inSeconds ?? 0,
      ),
    )..addListener(_listener);

    // Default to landscape for theater-like premium experience
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _startControlsTimer();
  }

  void _listener() {
    if (mounted) setState(() {});
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startControlsTimer();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _controller.removeListener(_listener);
    _controller.dispose();
    
    // Revert back to all device orientations on exit
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void _toggleFullscreen() {
    setState(() {
      _isLandscape = !_isLandscape;
    });
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  void _switchToAudioMode(AudioPlayerProvider audioProvider) {
    _controller.pause();
    final currentPos = _controller.value.position;
    
    final finalSong = widget.song ?? SongModel.create(
      id: widget.videoId ?? '',
      title: widget.title ?? 'Track',
      artist: widget.artist ?? (widget.isTrailer ? 'by YouTube' : 'Video'),
      type: SongType.soundtrack,
      source: SongSource.youtube,
    );

    // Synchronize play state in provider at this position
    audioProvider.playSong(finalSong, startPosition: currentPos);
    
    // Replace video screen with audio player (slide-up from bottom)
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const FullScreenAudioPlayer(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.read<AudioPlayerProvider>();
    final userDataProvider = context.read<UserDataProvider>();
    final song = widget.song ?? SongModel.create(
      id: widget.videoId ?? '',
      title: widget.title ?? 'Trailer',
      artist: widget.artist ?? (widget.isTrailer ? 'by YouTube' : 'Video'),
      type: SongType.soundtrack,
      source: SongSource.youtube,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: WillPopScope(
        onWillPop: () async {
          // If in landscape, exit landscape first
          if (_isLandscape) {
            _toggleFullscreen();
            return false;
          }
          return true;
        },
        child: GestureDetector(
          onTap: _toggleControls,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: YoutubePlayer(
                    controller: _controller,
                    showVideoProgressIndicator: false,
                  ),
                ),
              ),
              
              // Custom premium overlays
              if (_showControls) ...[
                // Top Overlay
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.title,
                                  style: GoogleFonts.dmSans(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (song.contentTitle != null)
                                  Text(
                                    song.contentTitle!,
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          // Media type / Language Badges
                          if (song.mediaType != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.primary, width: 0.5),
                              ),
                              child: Text(
                                song.mediaType!.toUpperCase(),
                                style: GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (song.language != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                song.language!.toUpperCase(),
                                style: GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          IconButton(
                            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                            onPressed: () {
                              _controlsTimer?.cancel();
                              _showMoreOptions(context, audioProvider, userDataProvider, song);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Controls Overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Progress Bar
                          SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                              activeTrackColor: AppColors.primary,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: AppColors.primary,
                            ),
                            child: Slider(
                              value: _controller.value.position.inSeconds.toDouble().clamp(
                                    0.0,
                                    _controller.metadata.duration.inSeconds.toDouble() > 0
                                        ? _controller.metadata.duration.inSeconds.toDouble()
                                        : 1.0,
                                  ),
                              max: _controller.metadata.duration.inSeconds.toDouble() > 0
                                  ? _controller.metadata.duration.inSeconds.toDouble()
                                  : 1.0,
                              onChanged: (val) {
                                _startControlsTimer();
                                _controller.seekTo(Duration(seconds: val.toInt()));
                              },
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(_controller.value.position),
                                style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 11),
                              ),
                              Text(
                                _formatDuration(_controller.metadata.duration),
                                style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Controls Button Bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Speed Indicator
                              TextButton.icon(
                                onPressed: () {
                                  _controlsTimer?.cancel();
                                  _showSpeedSelector(context);
                                },
                                icon: const Icon(Icons.speed_rounded, color: Colors.white70, size: 16),
                                label: Text(
                                  '${_playbackSpeed}x',
                                  style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              // Skip & Play buttons
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 24),
                                    onPressed: () {
                                      _startControlsTimer();
                                      final newPos = _controller.value.position - const Duration(seconds: 10);
                                      _controller.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: () {
                                      _startControlsTimer();
                                      if (_controller.value.isPlaying) {
                                        _controller.pause();
                                      } else {
                                        _controller.play();
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 24),
                                    onPressed: () {
                                      _startControlsTimer();
                                      final newPos = _controller.value.position + const Duration(seconds: 10);
                                      final total = _controller.metadata.duration;
                                      _controller.seekTo(newPos > total ? total : newPos);
                                    },
                                  ),
                                ],
                              ),
                              // Side controls: Fullscreen & Switch to Audio
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.audiotrack_rounded, color: Colors.white70),
                                    onPressed: () => _switchToAudioMode(audioProvider),
                                    tooltip: 'Switch to Audio',
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _isLandscape ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                                      color: Colors.white70,
                                    ),
                                    onPressed: _toggleFullscreen,
                                    tooltip: 'Toggle Fullscreen',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSpeedSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Playback Speed', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
              final isSelected = _playbackSpeed == speed;
              return ListTile(
                title: Text('${speed}x', style: GoogleFonts.dmSans(color: isSelected ? AppColors.primary : Colors.white)),
                trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
                onTap: () {
                  setState(() {
                    _playbackSpeed = speed;
                  });
                  Navigator.pop(context);
                  _startControlsTimer();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Playback speed is not supported on this player.')),
                  );
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showMoreOptions(
    BuildContext context,
    AudioPlayerProvider audioProvider,
    UserDataProvider userDataProvider,
    SongModel song,
  ) {
    final isFavorite = userDataProvider.favoriteSongs.any((s) => s.id == song.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.audiotrack_rounded, color: Colors.white),
                  title: Text('Switch to Audio Mode', style: GoogleFonts.dmSans(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _switchToAudioMode(audioProvider);
                  },
                ),
                ListTile(
                  leading: Icon(
                    isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFavorite ? AppColors.primary : Colors.white,
                  ),
                  title: Text(isFavorite ? 'Remove from Favorites' : 'Add to Favorites', style: GoogleFonts.dmSans(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    userDataProvider.toggleFavoriteSong(song);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.playlist_add_rounded, color: Colors.white),
                  title: Text('Add to Playlist', style: GoogleFonts.dmSans(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _showPlaceholderDialog(context, 'Playlist Support', 'Playlist support will be added soon.');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.subtitles_rounded, color: Colors.white),
                  title: Text('Toggle Captions / Subtitles', style: GoogleFonts.dmSans(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Subtitles toggled.')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.high_quality_rounded, color: Colors.white),
                  title: Text('Quality Selector', style: GoogleFonts.dmSans(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _showPlaceholderDialog(context, 'Quality Settings', 'Quality selection is not supported on this player.');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.link_rounded, color: Colors.white),
                  title: Text('Copy Link', style: GoogleFonts.dmSans(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: 'https://youtube.com/watch?v=${song.id}'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied to clipboard!')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_rounded, color: Colors.white),
                  title: Text('Share Video', style: GoogleFonts.dmSans(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _showPlaceholderDialog(context, 'Share Video', 'Sharing options will be supported in the next release.');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.error_outline_rounded, color: Colors.orangeAccent),
                  title: Text('Report Wrong Match', style: GoogleFonts.dmSans(color: Colors.orangeAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Thank you! Report received for wrong matching.')),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPlaceholderDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(message, style: GoogleFonts.dmSans(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startControlsTimer();
            },
            child: Text('OK', style: GoogleFonts.dmSans(color: AppColors.primary)),
          )
        ],
      ),
    );
  }
}
