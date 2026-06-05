import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:ui';

/// A custom media notification player mimicking the Android 13+ style.
/// It features a squiggly progress bar, a blurred album art background,
/// and smooth play/pause animations.
class CustomMediaNotification extends StatefulWidget {
  final String title;
  final String artist;
  final String? albumArtUrl;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Duration currentPosition;
  final Duration totalDuration;
  final ValueChanged<Duration>? onSeek;
  final String deviceName;

  const CustomMediaNotification({
    super.key,
    required this.title,
    required this.artist,
    this.albumArtUrl,
    this.isPlaying = false,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.currentPosition,
    required this.totalDuration,
    this.onSeek,
    this.deviceName = 'This phone',
  });

  @override
  State<CustomMediaNotification> createState() => _CustomMediaNotificationState();
}

class _CustomMediaNotificationState extends State<CustomMediaNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isPlaying) {
      _waveController.repeat();
    }
  }

  @override
  void didUpdateWidget(CustomMediaNotification oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _waveController.repeat();
      } else {
        _waveController.stop();
      }
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      height: 160,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Background Image
            if (widget.albumArtUrl != null)
              Positioned.fill(
                child: Image.network(
                  widget.albumArtUrl!,
                  fit: BoxFit.cover,
                ),
              ),
            
            // Gradient Overlay to ensure text readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            
            // Optional Blur Effect (Glassmorphism)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.2), // Dark tint
                ),
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row (App Icon & Device Chip)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // App Icon Placeholder (e.g., Flutter logo or back arrow)
                      const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      
                      // Device Output Chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE6EE), // Soft pinkish white
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.smartphone,
                              color: Colors.black87,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.deviceName,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const Spacer(),
                  
                  // Middle Row (Title, Artist & Play Button)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Play/Pause Button
                      GestureDetector(
                        onTap: widget.onPlayPause,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE6EE), // Soft pinkish highlight
                            borderRadius: BorderRadius.circular(20), // Rounded square
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, anim) =>
                                  ScaleTransition(scale: anim, child: child),
                              child: Icon(
                                widget.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                key: ValueKey(widget.isPlaying),
                                color: Colors.black87,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Bottom Row (Next/Prev + Progress Bar)
                  Row(
                    children: [
                      // Square button (Previous or stop based on the screenshot)
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onPrevious,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Squiggly Progress Bar
                      Expanded(
                        child: AnimatedBuilder(
                          animation: _waveController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: _SquigglyProgressPainter(
                                progress: widget.totalDuration.inMilliseconds == 0
                                    ? 0.0
                                    : widget.currentPosition.inMilliseconds /
                                        widget.totalDuration.inMilliseconds,
                                animationValue: _waveController.value,
                                isPlaying: widget.isPlaying,
                              ),
                              size: const Size(double.infinity, 24),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquigglyProgressPainter extends CustomPainter {
  final double progress;
  final double animationValue;
  final bool isPlaying;

  _SquigglyProgressPainter({
    required this.progress,
    required this.animationValue,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final thumbPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw unplayed track (straight line)
    final trackPath = Path();
    trackPath.moveTo(size.width * progress, size.height / 2);
    trackPath.lineTo(size.width, size.height / 2);
    canvas.drawPath(trackPath, trackPaint);

    // Draw played track (squiggly line)
    final progressPath = Path();
    final playedWidth = size.width * progress;
    progressPath.moveTo(0, size.height / 2);

    if (isPlaying && playedWidth > 0) {
      final waveCount = (playedWidth / 20).floor();
      final amplitude = 4.0;
      
      for (double i = 0; i <= playedWidth; i++) {
        // Shift wave backward over time to create a moving effect
        final offset = animationValue * pi * 2 * 3; // speed
        final y = size.height / 2 + sin((i / 10.0) - offset) * amplitude;
        progressPath.lineTo(i, y);
      }
    } else {
      progressPath.lineTo(playedWidth, size.height / 2);
    }

    canvas.drawPath(progressPath, progressPaint);

    // Draw thumb
    final thumbX = playedWidth;
    final thumbY = isPlaying 
      ? size.height / 2 + sin((playedWidth / 10.0) - (animationValue * pi * 2 * 3)) * 4.0 
      : size.height / 2;
      
    canvas.drawCircle(Offset(thumbX, thumbY), 6, thumbPaint);
  }

  @override
  bool shouldRepaint(covariant _SquigglyProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.animationValue != animationValue ||
           oldDelegate.isPlaying != isPlaying;
  }
}
