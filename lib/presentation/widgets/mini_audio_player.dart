import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/core/providers/audio_player_provider.dart';
import 'package:watch_track/presentation/screens/audio/full_screen_audio_player.dart';

class MiniAudioPlayer extends StatelessWidget {
  const MiniAudioPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.watch<AudioPlayerProvider>();
    final song = audioProvider.currentSong;

    if (song == null) return const SizedBox.shrink();

    return Dismissible(
      key: const Key('mini_audio_player'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) {
        audioProvider.closePlayer();
      },
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
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
        },
        child: Container(
          height: 72,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Stack(
                  children: [
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: song.thumbnailUrl != null
                                ? Image.network(
                                    song.thumbnailUrl!,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 52,
                                    height: 52,
                                    color: AppColors.surface,
                                    child: const Icon(
                                      Icons.music_note_rounded,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                style: GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                song.artist,
                                style: GoogleFonts.dmSans(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded),
                          color: Colors.white,
                          iconSize: 28,
                          onPressed: () {
                            audioProvider.previous();
                          },
                        ),
                        if (audioProvider.isBuffering)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14.0),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                                strokeWidth: 2.5,
                              ),
                            ),
                          )
                        else
                          IconButton(
                            icon: AnimatedSwitcher(
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
                            iconSize: 32,
                            onPressed: () {
                              audioProvider.togglePlayPause();
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded),
                          color: Colors.white,
                          iconSize: 28,
                          onPressed: () {
                            audioProvider.next();
                          },
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: StreamBuilder<Duration>(
                        stream: Stream.periodic(
                            const Duration(milliseconds: 500),
                            (_) => audioProvider.currentPosition),
                        builder: (context, snapshot) {
                          final current = audioProvider.currentPosition;
                          final total = audioProvider.totalDuration;
                          final progress = total.inMilliseconds > 0
                              ? (current.inMilliseconds / total.inMilliseconds)
                                  .clamp(0.0, 1.0)
                              : 0.0;
                          return ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(20)),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.transparent,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primary),
                              minHeight: 2,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
