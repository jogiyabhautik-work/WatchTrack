import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/core/services/stream_providers/stream_provider.dart';

class AdvancedVideoPlayer extends StatefulWidget {
  final String url;
  final String title;
  final List<StreamQuality>? qualities;

  const AdvancedVideoPlayer({
    super.key,
    required this.url,
    required this.title,
    this.qualities,
  });

  @override
  State<AdvancedVideoPlayer> createState() => _AdvancedVideoPlayerState();
}

class _AdvancedVideoPlayerState extends State<AdvancedVideoPlayer> {
  late VideoPlayerController _controller;
  bool _showControls = true;
  Timer? _controlsTimer;
  bool _isLandscape = true;
  double _playbackSpeed = 1.0;
  double _volume = 1.0;
  double _scale = 1.0;
  late String _currentUrl;

  // Gesture handling
  void _handleDoubleTapDown(TapDownDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(details.globalPosition);
    final width = box.size.width;
    final isLeft = localPos.dx < width / 2;
    final newPos = _controller.value.position + Duration(seconds: isLeft ? -10 : 10);
    _controller.seekTo(newPos);
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    setState(() => _scale = details.scale.clamp(0.5, 3.0));
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(details.globalPosition);
    final width = box.size.width;
    final dy = details.delta.dy;
    
    // Simple MX player style control: left = brightness (placeholder), right = volume
    if (localPos.dx > width / 2) {
      // Volume control
      setState(() {
        _volume = (_volume - dy / 200).clamp(0.0, 1.0);
        _controller.setVolume(_volume);
      });
    } else {
      // Brightness control (placeholder for now, could use screen_brightness plugin)
    }
  }

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _initializePlayer(_currentUrl);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _startControlsTimer();
  }

  void _initializePlayer(String url, {Duration? startAt, bool play = true}) {
    if (url.startsWith('http')) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(url));
    } else {
      _controller = VideoPlayerController.file(File(url));
    }
    
    _controller.initialize().then((_) {
        setState(() {});
        if (startAt != null) _controller.seekTo(startAt);
        if (play) _controller.play();
      });
      
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _changeQuality(String newUrl) async {
    final position = await _controller.position;
    final isPlaying = _controller.value.isPlaying;
    await _controller.dispose();
    setState(() { _currentUrl = newUrl; });
    _initializePlayer(newUrl, startAt: position, play: isPlaying);
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startControlsTimer();
  }

  void _toggleFullscreen() {
    setState(() => _isLandscape = !_isLandscape);
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _controller.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PopScope(
        canPop: !_isLandscape,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_isLandscape) {
            _toggleFullscreen();
          }
        },
        child: GestureDetector(
          onTap: _toggleControls,
          onDoubleTapDown: _handleDoubleTapDown,
          onScaleUpdate: _handleScaleUpdate,
          onVerticalDragUpdate: _handleVerticalDragUpdate,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              Center(
                child: _controller.value.isInitialized
                    ? Transform.scale(
                        scale: _scale,
                        child: AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        ),
                      )
                    : const CircularProgressIndicator(color: AppColors.primary),
              ),

              if (_showControls) ...[
                // Top Bar
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
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
                            child: Text(
                              widget.title,
                              style: GoogleFonts.dmSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Controls
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter, end: Alignment.topCenter,
                        colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_controller.value.isInitialized) ...[
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
                                value: _controller.value.position.inSeconds.toDouble().clamp(0.0, _controller.value.duration.inSeconds.toDouble()),
                                max: _controller.value.duration.inSeconds.toDouble() > 0 ? _controller.value.duration.inSeconds.toDouble() : 1.0,
                                onChanged: (val) {
                                  _startControlsTimer();
                                  _controller.seekTo(Duration(seconds: val.toInt()));
                                },
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDuration(_controller.value.position), style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 12)),
                                Text(_formatDuration(_controller.value.duration), style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      _controlsTimer?.cancel();
                                      _showSpeedSelector(context);
                                    },
                                    icon: const Icon(Icons.speed_rounded, color: Colors.white70, size: 16),
                                    label: Text('${_playbackSpeed}x', style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  if (widget.qualities != null && widget.qualities!.length > 1)
                                    TextButton.icon(
                                      onPressed: () {
                                        _controlsTimer?.cancel();
                                        _showQualitySelector(context);
                                      },
                                      icon: const Icon(Icons.hd_rounded, color: Colors.white70, size: 16),
                                      label: Text(
                                        widget.qualities!.firstWhere((q) => q.url == _currentUrl, orElse: () => widget.qualities!.first).quality, 
                                        style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)
                                      ),
                                    ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 28),
                                    onPressed: () {
                                      _startControlsTimer();
                                      final newPos = _controller.value.position - const Duration(seconds: 10);
                                      _controller.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
                                    },
                                  ),
                                  const SizedBox(width: 16),
                                  GestureDetector(
                                    onTap: () {
                                      _startControlsTimer();
                                      _controller.value.isPlaying ? _controller.pause() : _controller.play();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                      child: Icon(_controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 32),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 28),
                                    onPressed: () {
                                      _startControlsTimer();
                                      final newPos = _controller.value.position + const Duration(seconds: 10);
                                      _controller.seekTo(newPos > _controller.value.duration ? _controller.value.duration : newPos);
                                    },
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: Icon(_isLandscape ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, color: Colors.white70),
                                onPressed: _toggleFullscreen,
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
            children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
              final isSelected = _playbackSpeed == speed;
              return ListTile(
                title: Text('${speed}x', style: GoogleFonts.dmSans(color: isSelected ? AppColors.primary : Colors.white)),
                trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
                onTap: () {
                  setState(() => _playbackSpeed = speed);
                  _controller.setPlaybackSpeed(speed);
                  Navigator.pop(context);
                  _startControlsTimer();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showQualitySelector(BuildContext context) {
    if (widget.qualities == null) return;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Select Quality', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.qualities!.map((q) {
              final isSelected = _currentUrl == q.url;
              return ListTile(
                title: Text(q.quality, style: GoogleFonts.dmSans(color: isSelected ? AppColors.primary : Colors.white)),
                trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
                onTap: () {
                  if (!isSelected) {
                    _changeQuality(q.url);
                  }
                  Navigator.pop(context);
                  _startControlsTimer();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
