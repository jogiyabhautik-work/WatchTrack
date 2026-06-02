import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/data/models/movie_model.dart';
import 'package:watch_track/core/services/global_youtube_service.dart';
import 'package:watch_track/presentation/screens/audio/youtube_video_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class GlobalTrailerPlayer extends StatefulWidget {
  final Movie movie;
  
  const GlobalTrailerPlayer({super.key, required this.movie});

  @override
  State<GlobalTrailerPlayer> createState() => _GlobalTrailerPlayerState();
}

class _GlobalTrailerPlayerState extends State<GlobalTrailerPlayer> {
  final GlobalYouTubeService _youtubeService = GlobalYouTubeService();
  
  YoutubePlayerController? _controller;
  List<YouTubeVideoData> _videos = [];
  YouTubeVideoData? _selectedVideo;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchTrailers();
  }

  Future<void> _fetchTrailers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final videos = await _youtubeService.getTrailers(
        tmdbId: widget.movie.id,
        isMovie: widget.movie.isMovie,
        title: widget.movie.title,
        year: widget.movie.releaseDate.isNotEmpty ? widget.movie.releaseDate.substring(0, 4) : null,
      );

      if (mounted) {
        setState(() {
          _videos = videos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _playVideo(YouTubeVideoData video) {
    setState(() {
      _selectedVideo = video;
      _hasError = false;
    });
    
    if (_controller != null) {
      _controller!.load(video.id);
    } else {
      _controller = YoutubePlayerController(
        initialVideoId: video.id,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: true,
        ),
      );
    }
  }

  void _openFullscreenPlayer(YouTubeVideoData video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => YouTubeVideoScreen(
          videoId: video.id,
          song: null,
          title: video.title,
          artist: 'by YouTube',
          isTrailer: true,
        ),
      ),
    );
  }

  void _launchManualSearch() async {
    final query = '${widget.movie.title} official trailer';
    final url = Uri.parse('https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    if (_hasError) {
      return _buildErrorState();
    }

    if (_videos.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_selectedVideo != null) ...[
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: YoutubePlayerBuilder(
                player: YoutubePlayer(
                  controller: _controller!,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: AppColors.primary,
                ),
                builder: (context, player) => player,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Dynamic Title Overlay
        Text(
          _selectedVideo != null ? 'Currently Playing: ${_selectedVideo!.title}' : 'Select a Version to Play',
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (_selectedVideo != null) ...[
          const SizedBox(height: 4),
          Text(
            'by YouTube',
            style: GoogleFonts.dmSans(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 12),

        // Beautiful Card Selection UI
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _videos.length,
          itemBuilder: (context, index) {
            final video = _videos[index];
            final isPlaying = _selectedVideo?.id == video.id;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isPlaying ? AppColors.primary.withOpacity(0.08) : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPlaying ? AppColors.primary : AppColors.borderDefault,
                  width: isPlaying ? 1.5 : 0.5,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.network(
                        'https://img.youtube.com/vi/${video.id}/0.jpg',
                        width: 90,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 90,
                          height: 56,
                          color: Colors.black26,
                          child: const Icon(Icons.video_library_rounded, color: AppColors.textMuted),
                        ),
                      ),
                      Container(
                        width: 90,
                        height: 56,
                        color: Colors.black.withOpacity(0.3),
                      ),
                      const Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 24),
                    ],
                  ),
                ),
                title: Text(
                  video.title,
                  style: GoogleFonts.dmSans(
                    color: isPlaying ? AppColors.primary : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        video.language.toUpperCase(),
                        style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      video.type,
                      style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (video.isOfficial) ...[
                      const Icon(Icons.verified, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                    ],
                    IconButton(
                      icon: const Icon(Icons.fullscreen_rounded, color: Colors.white60),
                      onPressed: () => _openFullscreenPlayer(video),
                      tooltip: 'Play in Fullscreen',
                    ),
                  ],
                ),
                onTap: () => _playVideo(video),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off_outlined, color: AppColors.textMuted, size: 48),
          const SizedBox(height: 12),
          Text(
            'No official trailer is available yet.',
            style: GoogleFonts.dmSans(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _fetchTrailers,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _launchManualSearch,
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Search Manually'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 12),
          Text(
            'Video could not be loaded.',
            style: GoogleFonts.dmSans(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchTrailers,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry Connection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }
}
