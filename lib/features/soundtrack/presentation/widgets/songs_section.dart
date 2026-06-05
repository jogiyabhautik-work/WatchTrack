import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watch_track/features/soundtrack/domain/enums/song_type.dart';
import 'package:provider/provider.dart';
import 'package:watch_track/core/providers/audio_player_provider.dart';
import 'package:watch_track/core/providers/user_data_provider.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/features/soundtrack/domain/models/song_model.dart';
import 'package:watch_track/features/soundtrack/data/soundtrack_repository.dart';
import 'package:watch_track/presentation/screens/audio/youtube_video_screen.dart';
import 'package:watch_track/presentation/screens/audio/full_screen_audio_player.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchSongs();
  }

  Future<void> _fetchSongs() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

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
    final audioProvider = context.read<AudioPlayerProvider>();
    if (audioProvider.currentSong?.id == song.id) {
      audioProvider.togglePlayPause();
    } else {
      await audioProvider.playSong(song, queue: _songs);
      _openFullScreenPlayer();
    }
  }

  void _openFullScreenPlayer() {
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
  }

  void _openVideoPlayer(SongModel song) {
    final audioProvider = context.read<AudioPlayerProvider>();
    audioProvider.pause();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => YouTubeVideoScreen(
          song: song,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildSkeleton();
    }

    if (_errorMessage != null) {
      return _buildEmptyState(_errorMessage!, Icons.error_outline, showRetry: true);
    }

    if (_songs.isEmpty) {
      return _buildEmptyState(
        'No soundtrack found for this title.',
        Icons.music_off_outlined,
        showSearchAction: true,
        showRetry: true,
      );
    }

    final hasUncertainMatches = _songs.any((s) => !s.isLikelyAccurate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasUncertainMatches) ...[
          _buildVerificationBanner(),
          const SizedBox(height: 12),
        ],

        ..._songs.map((song) => _buildSongCard(song)),
      ],
    );
  }

  Widget _buildVerificationBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.orangeAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'We found possible soundtrack matches. Please verify before playing.',
              style: GoogleFonts.dmSans(
                color: Colors.orangeAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon, {bool showSearchAction = false, bool showRetry = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (showRetry) ...[
                  ElevatedButton.icon(
                    onPressed: _fetchSongs,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (showSearchAction) ...[
                  OutlinedButton.icon(
                    onPressed: () async {
                      final query = '${widget.title} official soundtrack';
                      final url = Uri.parse('https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('Search manually'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ]
              ],
            )
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
    final audioProvider = context.watch<AudioPlayerProvider>();
    final isSelected = audioProvider.currentSong?.id == song.id;
    Color typeColor = _getTypeColor(song.type);
    
    // Check if compilation or full album
    final isFullAlbum = song.title.toLowerCase().contains('full album') || 
                        song.title.toLowerCase().contains('compilation') || 
                        song.title.toLowerCase().contains('playlist');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.3) : AppColors.borderDefault, 
          width: isSelected ? 1.5 : 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _handleTap(song),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.1),
                        ),
                        child: Image.asset(
                          'assets/logo/default_soundtrack.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            _getIconForType(song.type),
                            color: typeColor,
                            size: 24,
                          ),
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
                              fontSize: 14,
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
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _buildBadge(song.type.displayName, typeColor),
                              if (song.episode != null && song.episode!.isNotEmpty)
                                _buildBadge('Ep: ${song.episode}', AppColors.textMuted),
                              if (song.duration != null && song.duration!.isNotEmpty)
                                _buildBadge(song.duration!, AppColors.textMuted),
                              if (song.isOfficial)
                                _buildBadge('OFFICIAL', AppColors.primary),
                              if (!song.isLikelyAccurate)
                                _buildBadge('POSSIBLE MATCH', Colors.orangeAccent),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.videocam_rounded, color: Colors.white60, size: 22),
                          onPressed: () => _openVideoPlayer(song),
                          tooltip: 'Play Video',
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert_rounded, color: Colors.white60, size: 22),
                          onPressed: () => _showSongOptions(context, song),
                          tooltip: 'Options',
                        ),
                      ],
                    ),
                  ],
                ),
                if (isFullAlbum) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Only full album/playlist found.',
                          style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 11),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => _handleTap(song),
                              child: Text(
                                'Play Full Album',
                                style: GoogleFonts.dmSans(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final query = '${widget.title} soundtracks';
                                final url = Uri.parse('https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}');
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Text(
                                'Search Songs',
                                style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSongOptions(BuildContext context, SongModel song) {
    final userDataProvider = context.read<UserDataProvider>();
    final audioProvider = context.read<AudioPlayerProvider>();
    final isFavorite = userDataProvider.favoriteSongs.any((s) => s.id == song.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
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
                leading: const Icon(Icons.queue_rounded, color: Colors.white),
                title: Text('Add to Queue', style: GoogleFonts.dmSans(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  audioProvider.addSongToQueue(song);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added to Queue: ${song.title}')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded, color: Colors.white),
                title: Text('Copy Song Link', style: GoogleFonts.dmSans(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: 'https://youtube.com/watch?v=${song.id}'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Song link copied to clipboard!')),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
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
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.dmSans(color: AppColors.primary)),
          )
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
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
