import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:youtube_player_flutter/youtube_player_flutter.dart' hide PlayerState;
import 'package:youtube_player_flutter/src/enums/player_state.dart' as yt;
import 'package:watch_track/features/soundtrack/services/youtube_service.dart';
import 'package:watch_track/features/soundtrack/presentation/screens/theme_video_player_screen.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/features/soundtrack/data/soundtrack_repository.dart';
import 'package:watch_track/features/soundtrack/domain/models/song_model.dart';
import 'package:watch_track/features/soundtrack/domain/enums/song_type.dart';
import 'package:watch_track/features/soundtrack/domain/enums/song_source.dart';

class SongsSection extends StatefulWidget {
  final String mediaId;
  final String title;
  final bool isAnime;
  final bool isMovie;

  const SongsSection({
    super.key,
    required this.mediaId,
    required this.title,
    required this.isAnime,
    required this.isMovie,
  });

  @override
  State<SongsSection> createState() => _SongsSectionState();
}

class _SongsSectionState extends State<SongsSection> {
  final SoundtrackRepository _repository = SoundtrackRepository();
  List<SongModel> _songs = [];
  bool _isLoading = true;
  String? _errorMessage;

  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();
  YoutubePlayerController? _ytController;
  String? _currentlyPlayingUrl; // Also used for YouTube videoId
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _fetchSongs();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == ap.PlayerState.playing;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentlyPlayingUrl = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _ytController?.dispose();
    super.dispose();
  }

  Future<void> _fetchSongs() async {
    try {
      final songs = await _repository.getSongs(
        mediaId: widget.mediaId,
        title: widget.title,
        isAnime: widget.isAnime,
        isMovie: widget.isMovie,
      );
      if (mounted) {
        setState(() {
          _songs = songs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load soundtrack.';
          _isLoading = false;
        });
      }
    }
  }

  void _handleTap(SongModel song) async {
    final url = song.externalUrl;
    if (url == null || url.isEmpty) return;

    if (song.source == SongSource.animeThemes) {
      // It's a video link from AnimeThemes
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ThemeVideoPlayerScreen(url: url, title: song.title),
        ),
      );
    } else if (song.source == SongSource.youtube) {
      // It's a YouTube track, play natively using hidden YoutubePlayer
      if (_currentlyPlayingUrl == song.id) {
        if (_isPlaying) {
          _ytController?.pause();
        } else {
          _ytController?.play();
        }
      } else {
        // Stop any currently playing audio
        await _audioPlayer.stop();
        _ytController?.pause();

        setState(() {
          _currentlyPlayingUrl = song.id;
          _isPlaying = true;
        });
        
        if (_ytController == null) {
          _ytController = YoutubePlayerController(
            initialVideoId: song.id,
            flags: const YoutubePlayerFlags(
              autoPlay: true,
              hideControls: true,
              disableDragSeek: true,
              isLive: false,
            ),
          )..addListener(() {
              if (_ytController!.value.playerState == yt.PlayerState.playing) {
                if (!_isPlaying && mounted) setState(() => _isPlaying = true);
              } else if (_ytController!.value.playerState == yt.PlayerState.paused) {
                if (_isPlaying && mounted) setState(() => _isPlaying = false);
              } else if (_ytController!.value.playerState == yt.PlayerState.ended) {
                if (mounted) setState(() {
                  _isPlaying = false;
                  _currentlyPlayingUrl = null;
                });
              }
            });
        } else {
          _ytController?.load(song.id);
        }
      }
    } else {
      // It's an audio preview from iTunes (fallback)
      if (_currentlyPlayingUrl == url) {
        if (_isPlaying) {
          await _audioPlayer.pause();
        } else {
          await _audioPlayer.resume();
        }
      } else {
        await _audioPlayer.stop();
        setState(() {
          _currentlyPlayingUrl = url;
        });
        await _audioPlayer.play(ap.UrlSource(url));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildSkeleton();
    }

    if (_errorMessage != null) {
      return _buildEmptyState(_errorMessage!, Icons.error_outline);
    }

    if (_songs.isEmpty) {
      return _buildEmptyState(
        'No soundtrack data available for this ${widget.isAnime ? 'anime' : widget.isMovie ? 'movie' : 'series'}.',
        Icons.music_off_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isMovie || !widget.isAnime) ...[
          Text(
            'Powered by YouTube',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
        ],
        ..._songs.map((song) => _buildSongCard(song)).toList(),
        if (_ytController != null)
          SizedBox(
            width: 1,
            height: 1,
            child: Offstage(
              offstage: true,
              child: YoutubePlayer(
                controller: _ytController!,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surface2,
      child: Column(
        children: List.generate(
          3,
          (index) => Container(
            height: 80,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSongCard(SongModel song) {
    Color typeColor = _getTypeColor(song.type);
    final isThisPlaying = (_currentlyPlayingUrl == song.externalUrl || _currentlyPlayingUrl == song.id) && _isPlaying;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isThisPlaying ? typeColor : AppColors.borderDefault, 
          width: isThisPlaying ? 1.5 : 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: song.externalUrl != null ? () => _handleTap(song) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                    ),
                    child: song.thumbnailUrl != null
                        ? Image.network(
                            song.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              _getIconForType(song.type),
                              color: typeColor,
                              size: 24,
                            ),
                          )
                        : Icon(
                            _getIconForType(song.type),
                            color: typeColor,
                            size: 24,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
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
                      const SizedBox(height: 4),
                      Text(
                        song.artist,
                        style: GoogleFonts.dmSans(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildBadge(song.type.displayName, typeColor),
                          if (song.episode != null && song.episode!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _buildBadge('Ep: ${song.episode}', AppColors.textMuted),
                          ],
                          if (song.duration != null) ...[
                            const SizedBox(width: 8),
                            _buildBadge(song.duration!, AppColors.textMuted),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (song.externalUrl != null) ...[
                  const SizedBox(width: 12),
                  Icon(
                    song.source == SongSource.animeThemes
                        ? Icons.play_circle_outline_rounded 
                        : (isThisPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_outline_rounded),
                    color: isThisPlaying ? typeColor : Colors.white38,
                    size: 32,
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.dmSans(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _getTypeColor(SongType type) {
    switch (type) {
      case SongType.opening:
        return Colors.greenAccent;
      case SongType.ending:
        return Colors.orangeAccent;
      case SongType.insert:
        return Colors.purpleAccent;
      case SongType.soundtrack:
        return Colors.lightBlueAccent;
      case SongType.unknown:
        return AppColors.textMuted;
    }
  }

  IconData _getIconForType(SongType type) {
    switch (type) {
      case SongType.opening:
        return Icons.rocket_launch_rounded;
      case SongType.ending:
        return Icons.waving_hand_rounded;
      case SongType.insert:
        return Icons.music_note_rounded;
      case SongType.soundtrack:
        return Icons.album_rounded;
      case SongType.unknown:
        return Icons.audiotrack_rounded;
    }
  }
}
