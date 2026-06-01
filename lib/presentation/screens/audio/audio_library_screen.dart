import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/core/providers/user_data_provider.dart';
import 'package:watch_track/core/providers/audio_player_provider.dart';
import 'package:watch_track/core/services/global_youtube_service.dart';
import 'package:watch_track/features/soundtrack/domain/models/song_model.dart';
import 'dart:async';

class AudioLibraryScreen extends StatefulWidget {
  const AudioLibraryScreen({super.key});

  @override
  State<AudioLibraryScreen> createState() => _AudioLibraryScreenState();
}

class _AudioLibraryScreenState extends State<AudioLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  
  bool _isSearching = false;
  bool _isLoading = false;
  String _lastQuery = '';
  List<SongModel> _searchResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      if (query.trim().isEmpty) {
        setState(() {
          _isSearching = false;
          _searchResults.clear();
          _lastQuery = '';
        });
        return;
      }
      
      if (query == _lastQuery) return;
      
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _isLoading = true;
      _lastQuery = query;
    });

    final results = await GlobalYouTubeService().searchSongs(query);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // Background gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.6, -0.8),
                    radius: 1.2,
                    colors: [
                      AppColors.primary.withOpacity(0.12),
                      AppColors.background,
                    ],
                  ),
                ),
              ),
            ),
            
            // Content
            SafeArea(
              child: Consumer<UserDataProvider>(
                builder: (context, userData, child) {
                  final favoriteSongs = userData.favoriteSongs;
                  final displaySongs = _isSearching ? _searchResults : favoriteSongs;
                  
                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // Header & Search Bar
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Music',
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  if (!_isSearching)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        '${favoriteSongs.length} Liked',
                                        style: GoogleFonts.dmSans(
                                          color: AppColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              // Search Bar
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  style: GoogleFonts.dmSans(color: Colors.white),
                                  onChanged: _onSearchChanged,
                                  decoration: InputDecoration(
                                    hintText: 'Search for any song on YouTube...',
                                    hintStyle: GoogleFonts.dmSans(color: AppColors.textMuted),
                                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                                    suffixIcon: _searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                                            onPressed: () {
                                              _searchController.clear();
                                              _onSearchChanged('');
                                            },
                                          )
                                        : null,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  ),
                                ),
                              ),
                              if (_isSearching && !_isLoading) ...[
                                const SizedBox(height: 24),
                                Text(
                                  'Top Results',
                                  style: GoogleFonts.dmSans(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      
                      if (_isLoading)
                        const SliverFillRemaining(
                          child: Center(
                            child: CircularProgressIndicator(color: AppColors.primary),
                          ),
                        )
                      else if (displaySongs.isEmpty)
                        SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isSearching ? Icons.search_off_rounded : Icons.library_music_rounded,
                                  size: 80,
                                  color: Colors.white.withOpacity(0.1),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _isSearching ? 'No Results Found' : 'No Favorites Yet',
                                  style: GoogleFonts.dmSans(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _isSearching 
                                      ? 'Try searching for something else.' 
                                      : 'Search for a song and tap the heart icon.',
                                  style: GoogleFonts.dmSans(
                                    color: AppColors.textMuted,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.only(bottom: 120),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final song = displaySongs[index];
                                return Builder(
                                  builder: (context) {
                                    final isPlaying = context.select<AudioPlayerProvider, bool>(
                                      (p) => p.currentSong?.id == song.id,
                                    );
                                    final isFav = favoriteSongs.any((s) => s.id == song.id);

                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: song.thumbnailUrl != null
                                            ? Image.network(
                                                song.thumbnailUrl!,
                                                width: 56,
                                                height: 56,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                width: 56,
                                                height: 56,
                                                color: AppColors.surface,
                                                child: const Icon(Icons.music_note, color: AppColors.textMuted),
                                              ),
                                      ),
                                      title: Text(
                                        song.title,
                                        style: GoogleFonts.dmSans(
                                          color: isPlaying ? AppColors.primary : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        song.artist,
                                        style: GoogleFonts.dmSans(
                                          color: AppColors.textMuted,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: IconButton(
                                        icon: Icon(
                                          isFav ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                                          color: isFav ? AppColors.primary : AppColors.textMuted,
                                        ),
                                        onPressed: () => userData.toggleFavoriteSong(song),
                                      ),
                                      onTap: () {
                                        final audioProvider = context.read<AudioPlayerProvider>();
                                        if (isPlaying) {
                                          audioProvider.togglePlayPause();
                                        } else {
                                          audioProvider.playSong(song, queue: displaySongs);
                                        }
                                      },
                                    );
                                  },
                                );
                              },
                              childCount: displaySongs.length,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
