import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:watch_track/presentation/widgets/movie_card.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/data/models/movie_model.dart';
import 'package:watch_track/back-end/api_service.dart';
import 'package:watch_track/presentation/screens/genre/genre_screen.dart';
import 'package:watch_track/presentation/screens/actor/actor_detail_screen.dart';
import 'package:watch_track/core/providers/user_data_provider.dart';
import 'package:watch_track/core/providers/tracking_provider.dart';
import 'package:watch_track/core/providers/watchlist_folder_provider.dart';
import 'package:watch_track/data/models/user_title_model.dart';
import 'package:watch_track/presentation/widgets/watchlist_action_sheet.dart';
import 'package:watch_track/presentation/widgets/watchlist_action_sheet.dart';
import 'package:watch_track/core/utils/adaptive_theme_helper.dart';
import 'package:watch_track/features/soundtrack/presentation/widgets/songs_section.dart';
import 'package:watch_track/presentation/widgets/global_trailer_player.dart';

class DetailScreen extends StatefulWidget {
  final Movie movie;
  final String? heroTag;

  const DetailScreen({super.key, required this.movie, this.heroTag});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final ApiService _apiService = ApiService();
  Movie? _fullMovie;
  List<Movie> _similarMovies = [];
  bool _isLoadingDetails = true;
  bool _isLoadingSimilar = true;
  String? _detailsError;
  bool _isNavigating = false;

  bool _isTrailerMode = false;

  @override
  void dispose() {
    super.dispose();
  }

  // Persistence across session
  bool _isExpanded = false;

  // Adaptive Theming
  Color _accentColor = AppColors.primary;
  PaletteGenerator? _palette;

  // Tabs
  int _selectedTab = 0; // 0 = Details, 1 = Reviews
  List<Review> _reviews = [];
  bool _isLoadingReviews = false;

  // Cache for seasons to prevent re-fetching
  final Map<int, List<Episode>> _seasonCache = {};

  @override
  void initState() {
    super.initState();
    _loadAllContent();
    _updateAccentColor(widget.movie.posterPath);
  }

  Future<void> _loadAllContent({bool forceRefresh = false}) async {
    _loadEnrichedDetails(forceRefresh: forceRefresh);
    _loadSimilarContent(forceRefresh: forceRefresh);
  }

  Future<void> _loadEnrichedDetails({bool forceRefresh = false}) async {
    try {
      final details = await _apiService.getMovieById(widget.movie.id,
          isMovie: widget.movie.isMovie, forceRefresh: forceRefresh);
      if (mounted && details != null) {
        setState(() {
          _fullMovie = details;
          _isLoadingDetails = false;
        });
        _updateAccentColor(details.posterPath);
      } else if (mounted) {
        setState(() => _isLoadingDetails = false);
      }
      _fetchReviews();
    } catch (e) {
      if (mounted) {
        setState(() {
          _detailsError = "Failed to load extended info";
          _isLoadingDetails = false;
        });
      }
    }
  }

  Future<void> _loadSimilarContent({bool forceRefresh = false}) async {
    try {
      final similar = await _apiService.getSimilarContent(widget.movie.id,
          isMovie: widget.movie.isMovie, forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _similarMovies = similar;
          _isLoadingSimilar = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSimilar = false);
    }
  }

  void _safeNavigate(Widget screen, {bool replacement = false}) async {
    if (_isNavigating) return;
    _isNavigating = true;
    if (replacement) {
      await Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => screen));
    } else {
      await Navigator.push(
          context, MaterialPageRoute(builder: (context) => screen));
    }
    _isNavigating = false;
  }

  void _playTrailer(Movie movie) async {
    setState(() {
      _isTrailerMode = true;
    });
  }

  void _showWatchlistSheet(BuildContext context, Movie movie) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => WatchlistActionSheet(movie: movie),
    );
  }

  Future<void> _updateAccentColor(String imageUrl) async {
    if (imageUrl.isEmpty) return;
    final palette = await AdaptiveThemeHelper.getPalette(imageUrl);
    if (palette != null && mounted) {
      setState(() {
        _palette = palette;
        _accentColor = palette.vibrantColor?.color ?? 
                       palette.dominantColor?.color ?? 
                       AppColors.primary;
      });
    }
  }

  Future<void> _fetchReviews({bool forceRefresh = false}) async {
    setState(() => _isLoadingReviews = true);
    try {
      final reviews = await _apiService.getReviews(
        widget.movie.id,
        isMovie: widget.movie.isMovie,
        forceRefresh: forceRefresh,
      );
      if (mounted) setState(() => _reviews = reviews);
    } catch (e) {
      debugPrint('Error fetching reviews: $e');
    } finally {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  void _shareMovie(Movie movie) {
    final type = movie.isMovie ? 'movie' : 'tv';
    final url = 'https://www.themoviedb.org/$type/${movie.id}';
    Share.share('🎬 Check out "${movie.title}" on WatchTrack!\n$url');
  }

  Future<void> _handleRefresh() async {
    await _loadAllContent(forceRefresh: true);
    await _fetchReviews(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final movie = _fullMovie ?? widget.movie;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Dynamic Background Layer
          _buildCinematicBackground(movie),
          
          RefreshIndicator(
            onRefresh: _handleRefresh,
            backgroundColor: AppColors.surface,
            color: _accentColor,
            child: CustomScrollView(
              key: PageStorageKey('detail_${widget.movie.id}'),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                _buildSliverHeader(movie),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),
                        _buildCinematicMetaGrid(movie),
                        const SizedBox(height: 40),
                        _buildTabs(),
                        const SizedBox(height: 32),
                        if (_selectedTab == 0)
                          _buildDetailsTab(movie)
                        else if (_selectedTab == 1)
                          _buildReviewsTab()
                        else
                          _buildSoundtrackTab(movie),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildCinematicBackground(Movie movie) {
    return Positioned.fill(
      child: Stack(
        children: [
          Hero(
            tag: (widget.heroTag?.startsWith('daily_') ?? false) || (widget.heroTag?.startsWith('spotlight_') ?? false)
                ? widget.heroTag!
                : 'movie_bg_${movie.id}',
            child: CachedNetworkImage(
              imageUrl: movie.backdropPath,
              fit: BoxFit.cover,
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              color: Colors.black.withOpacity(0.6),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                  Colors.black,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCinematicMetaGrid(Movie movie) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildMetaItem('DURATION', movie.runtime.isNotEmpty ? movie.runtime : '--'),
        _buildMetaItem('RELEASE', movie.releaseDate.split('-').first),
        _buildMetaItem('RATING', movie.rating.toString()),
        _buildMetaItem('AGE', movie.ageRating.isNotEmpty ? movie.ageRating : 'NR'),
      ],
    );
  }

  Widget _buildMetaItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSliverHeader(Movie movie) {
    return SliverAppBar(
      expandedHeight: 400,
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.black26,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      actions: _isTrailerMode
          ? [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black26,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: () {
                      setState(() {
                        _isTrailerMode = false;
                      });
                    },
                  ),
                ),
              ),
            ]
          : null,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Positioned.fill(
              child: Hero(
                tag: (widget.heroTag?.startsWith('daily_') ?? false) || (widget.heroTag?.startsWith('spotlight_') ?? false)
                    ? 'movie_poster_${movie.id}'
                    : widget.heroTag ?? 'movie_${movie.id}',
                child: CachedNetworkImage(
                  imageUrl: movie.posterPath,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (_isTrailerMode)
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 56.0,
                      left: 16,
                      right: 16,
                      bottom: 16,
                    ),
                    child: GlobalTrailerPlayer(movie: widget.movie),
                  ),
                ),
              ),
            if (!_isTrailerMode) ...[
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.5, 0.8, 1.0],
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                          Colors.black,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 40,
                left: 24,
                right: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title.toUpperCase(),
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 0.9,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: movie.genres.take(3).map((g) => Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white30),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(g, style: GoogleFonts.dmSans(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.bold)),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(Movie movie) {
    final List<String> metaItems = [
      movie.releaseDate.split('-').first,
      if (movie.runtime.isNotEmpty) movie.runtime,
      if (movie.ageRating.isNotEmpty) movie.ageRating,
    ];

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              ...metaItems
                  .expand((item) => [
                        Flexible(
                          child: Text(
                            item,
                            style: GoogleFonts.dmSans(
                                color: AppColors.textMuted, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('•',
                              style: GoogleFonts.dmSans(
                                  color: AppColors.textMuted)),
                        ),
                      ])
                  .toList()
                ..removeLast(),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildScoreBadge('IMDb', '8.4', Colors.yellow[700]!),
        const SizedBox(width: 8),
        _buildScoreBadge('RT', '92%', Colors.red),
      ],
    );
  }

  Widget _buildScoreBadge(String label, String score, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: GoogleFonts.dmSans(
                  color: color, fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(score,
              style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Movie movie) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => _playTrailer(movie),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              '▶  PLAY TRAILER',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Consumer<TrackingProvider>(
                builder: (context, tracking, _) {
                  final t = tracking.getTracking(int.tryParse(movie.id) ?? 0);
                  final inWatchlist = t != null;
                  return OutlinedButton.icon(
                    onPressed: () {
                      if (inWatchlist) {
                        tracking.removeTracking(int.tryParse(movie.id) ?? 0);
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Removed from Watchlist',
                              style: GoogleFonts.dmSans(fontSize: 13),
                            ),
                            backgroundColor: AppColors.surface2,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else {
                        _showWatchlistSheet(context, movie);
                      }
                    },
                    icon: Icon(
                      inWatchlist
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_add_outlined,
                      size: 18,
                    ),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          inWatchlist ? 'SAVED' : 'WATCHLIST',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (inWatchlist && t.syncStatus != SyncStatus.synced) ...[
                          const SizedBox(width: 4),
                          _buildSmallSyncIndicator(t.syncStatus),
                        ],
                      ],
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: inWatchlist
                              ? _accentColor
                              : AppColors.borderDefault),
                      foregroundColor: inWatchlist
                          ? _accentColor
                          : AppColors.textSecondary,
                      backgroundColor: inWatchlist
                          ? _accentColor.withOpacity(0.05)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: GoogleFonts.dmSans(
                          fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Consumer<TrackingProvider>(
              builder: (context, tracking, _) {
                final t = tracking.getTracking(int.tryParse(movie.id) ?? 0);
                final isFav = t?.isFavorite ?? false;
                return _IconActionButton(
                  icon: isFav
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFav ? Colors.pinkAccent : AppColors.textSecondary,
                  bgColor: isFav
                      ? Colors.pinkAccent.withOpacity(0.12)
                      : AppColors.surface,
                  tooltip: isFav ? 'Remove favourite' : 'Add to favourites',
                  onTap: () {
                    tracking.toggleFavorite(movie);
                    HapticFeedback.lightImpact();
                  },
                );
              },
            ),
            const SizedBox(width: 8),
            _IconActionButton(
              icon: Icons.ios_share_rounded,
              color: AppColors.textSecondary,
              bgColor: AppColors.surface,
              tooltip: 'Share',
              onTap: () => _shareMovie(movie),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserRatingSection(Movie movie) {
    return Consumer<TrackingProvider>(
      builder: (context, tracking, child) {
        final t = tracking.getTracking(int.tryParse(movie.id) ?? 0);
        final canRate = t != null;
        final currentRating = t?.userRating ?? 0.0;

        if (!canRate) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.borderDefault, width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded,
                    color: AppColors.textMuted, size: 16),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add this ${movie.isMovie ? 'movie' : 'show'} to your library to unlock ratings.',
                    style:
                        GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 11),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YOUR RATING',
              style: GoogleFonts.dmSans(
                color: AppColors.textMuted,
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (index) {
                final starValue = (index + 1) * 2.0;
                final isSelected = currentRating >= starValue;
                return GestureDetector(
                  onTap: () {
                    tracking.rateMovie(movie, starValue);
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Icon(
                      isSelected
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: isSelected
                          ? AppColors.ratingGold
                          : AppColors.textMuted,
                      size: 28,
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSynopsisSection(Movie movie) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SYNOPSIS',
          style: GoogleFonts.dmSans(
            color: Colors.white38,
            fontSize: 10,
            letterSpacing: 3,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          movie.overview,
          maxLines: _isExpanded ? null : 4,
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontSize: 15,
            height: 1.8,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Text(
            _isExpanded ? 'READ LESS' : 'READ FULL STORY',
            style: GoogleFonts.dmSans(
              color: _accentColor,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContentAdvisory(Movie movie) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONTENT ADVISORY',
          style: GoogleFonts.dmSans(
            color: Colors.white38,
            fontSize: 10,
            letterSpacing: 3,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        ...movie.contentWarnings
            .map((warning) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        warning.category.toUpperCase(),
                        style: GoogleFonts.dmSans(color: _accentColor, fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        warning.description,
                        style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ],
    );
  }

  Widget _buildCastSection(Movie movie) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TOP CAST',
          style: GoogleFonts.dmSans(
            color: Colors.white38,
            fontSize: 10,
            letterSpacing: 3,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 160,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: movie.cast.length,
            itemBuilder: (context, index) {
              final actor = movie.cast[index];
              return GestureDetector(
                onTap: () =>
                    _safeNavigate(ActorDetailScreen(actorId: actor.id)),
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 20),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 100,
                          width: 100,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            image: actor.profilePath.isNotEmpty
                                ? DecorationImage(image: CachedNetworkImageProvider(actor.profilePath), fit: BoxFit.cover)
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        actor.name,
                        style: GoogleFonts.dmSans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        actor.character,
                        style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 10),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationsSection(Movie movie) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MORE LIKE THIS',
          style: GoogleFonts.dmSans(
            color: AppColors.textMuted,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: _isLoadingSimilar
              ? _buildHorizontalShimmer(120)
              : _similarMovies.isEmpty
                  ? Center(
                      child: Text(
                        'No recommendations available',
                        style: GoogleFonts.dmSans(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _similarMovies.length,
                      itemBuilder: (context, index) {
                        final m = _similarMovies[index];
                        return MovieCard(
                          posterUrl: m.posterPath,
                          title: m.title,
                          rating: m.rating,
                          heroTag: 'similar_${m.id}',
                          onTap: () => _safeNavigate(
                              DetailScreen(movie: m),
                              replacement: true),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSeasonsSection(Movie movie) {
    if (movie.isMovie || movie.seasons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Text(
          'SEASONS',
          style: GoogleFonts.dmSans(
            color: AppColors.textMuted,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...movie.seasons
            .map((season) => SeasonTile(
                  tvId: movie.id,
                  season: season,
                  apiService: _apiService,
                  movie: movie,
                  accentColor: _accentColor,
                ))
            .toList(),
      ],
    );
  }

  Widget _buildWatchProvidersSection(Movie movie) {
    if (movie.watchProviders.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'WHERE TO WATCH',
          style: GoogleFonts.dmSans(
            color: AppColors.textMuted,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: movie.watchProviders.length,
            itemBuilder: (context, index) {
              final provider = movie.watchProviders[index];
              return Container(
                margin: const EdgeInsets.only(right: 12),
                child: Tooltip(
                  message: provider.name,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: provider.logoPath,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: AppColors.surface2),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.surface2,
                        child: const Icon(Icons.play_arrow,
                            color: Colors.white30, size: 20),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLanguagesSection(Movie movie) {
    if (movie.spokenLanguages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'AVAILABLE LANGUAGES',
          style: GoogleFonts.dmSans(
            color: AppColors.textMuted,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: movie.spokenLanguages
              .map((lang) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppColors.borderDefault, width: 0.5),
                    ),
                    child: Text(
                      lang,
                      style: GoogleFonts.dmSans(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSectionSkeleton(double height) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surface2,
      child: Container(
          height: height,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8))),
    );
  }

  Widget _buildHorizontalShimmer(double width) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surface2,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        itemBuilder: (context, index) => Container(
            width: width,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  Widget _buildCastSkeleton() {
    return _buildHorizontalShimmer(80);
  }

  Widget _buildEpisodeSkeleton() {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surface2,
      child: Column(
          children: List.generate(
        2,
        (index) => Container(
            height: 100,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12))),
      )),
    );
  }

  Widget _buildSmallSyncIndicator(SyncStatus status) {
    if (status == SyncStatus.synced) return const SizedBox.shrink();

    IconData icon;
    Color color;

    switch (status) {
      case SyncStatus.pending:
        icon = Icons.cloud_queue_rounded;
        color = Colors.orange;
        break;
      case SyncStatus.syncing:
        icon = Icons.sync_rounded;
        color = _accentColor;
        break;
      case SyncStatus.failed:
        icon = Icons.cloud_off_rounded;
        color = Colors.red;
        break;
      default:
        return const SizedBox.shrink();
    }

    if (status == SyncStatus.syncing) {
      return SizedBox(
        width: 10,
        height: 10,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
        ),
      );
    }

    return Icon(icon, color: color, size: 12);
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildTabItem(0, 'DETAILS'),
          _buildTabItem(1, 'REVIEWS'),
          _buildTabItem(2, 'SOUNDTRACK'),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTab = index);
          HapticFeedback.selectionClick();
        },
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? _accentColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              color: isSelected ? Colors.white : AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsTab(Movie movie) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMetaRow(movie),
        const SizedBox(height: 24),
        _buildActionButtons(movie),
        const SizedBox(height: 16),
        _buildUserRatingSection(movie),
        if (_isLoadingDetails)
          _buildSectionSkeleton(40)
        else
          _buildWatchProvidersSection(movie),
        const SizedBox(height: 32),
        _buildSynopsisSection(movie),
        if (_isLoadingDetails)
          _buildSectionSkeleton(30)
        else
          _buildLanguagesSection(movie),
        if (!movie.isMovie) ...[
          if (_isLoadingDetails)
            _buildSectionSkeleton(100)
          else
            _buildSeasonsSection(movie),
        ],
        const SizedBox(height: 24),
        if (movie.contentWarnings.isNotEmpty)
          _buildContentAdvisory(movie),
        const SizedBox(height: 32),
        if (_isLoadingDetails)
          _buildCastSkeleton()
        else if (movie.cast.isNotEmpty)
          RepaintBoundary(child: _buildCastSection(movie)),
        const SizedBox(height: 32),
        RepaintBoundary(child: _buildRecommendationsSection(movie)),
      ],
    );
  }

  Widget _buildReviewsTab() {
    if (_isLoadingReviews && _reviews.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_reviews.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.rate_review_outlined, 
                  size: 48, color: Colors.white.withOpacity(0.1)),
              const SizedBox(height: 16),
              Text(
                'No reviews yet',
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

    return Column(
      children: _reviews.map((review) => _buildReviewCard(review)).toList(),
    );
  }

  Widget _buildReviewCard(Review review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDefault, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surface2,
                backgroundImage: review.authorProfilePath.isNotEmpty
                    ? CachedNetworkImageProvider(review.authorProfilePath)
                    : null,
                child: review.authorProfilePath.isEmpty
                    ? Text(review.author[0].toUpperCase(), 
                        style: const TextStyle(color: Colors.white70, fontSize: 12))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.author,
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      review.createdAt.split('T').first,
                      style: GoogleFonts.dmSans(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (review.rating != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.ratingGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, 
                          color: AppColors.ratingGold, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        review.rating!.toStringAsFixed(1),
                        style: GoogleFonts.dmSans(
                          color: AppColors.ratingGold,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.content,
            style: GoogleFonts.dmSans(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSoundtrackTab(Movie movie) {
    return SongsSection(
      mediaId: movie.id,
      title: movie.title,
      isAnime: false,
      isMovie: movie.isMovie,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL ICON-ONLY ACTION BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String tooltip;
  final VoidCallback onTap;

  const _IconActionButton({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderDefault, width: 0.5),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SeasonTile
// ─────────────────────────────────────────────────────────────────────────────

class SeasonTile extends StatefulWidget {
  final String tvId;
  final Season season;
  final ApiService apiService;
  final Movie movie;
  final Color accentColor;

  const SeasonTile({
    super.key,
    required this.tvId,
    required this.season,
    required this.apiService,
    required this.movie,
    required this.accentColor,
  });

  @override
  State<SeasonTile> createState() => _SeasonTileState();
}

class _SeasonTileState extends State<SeasonTile> {
  bool _isLoading = false;
  Season? _fullSeason;
  String? _error;

  Future<void> _loadSeasonDetails() async {
    if (_fullSeason != null || _isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final details = await widget.apiService
          .getSeasonDetails(widget.tvId, widget.season.seasonNumber);
      if (mounted) {
        setState(() {
          _fullSeason = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load episodes';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTileTheme(
      data: const ExpansionTileThemeData(),
      child: ExpansionTile(
        key: PageStorageKey('season_${widget.season.seasonNumber}'),
        tilePadding: EdgeInsets.zero,
        onExpansionChanged: (expanded) {
          if (expanded) _loadSeasonDetails();
        },
        title: Text(
          widget.season.name,
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${widget.season.episodeCount} Episodes',
          style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CachedNetworkImage(
            imageUrl: widget.season.posterPath,
            width: 45,
            height: 65,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                Container(color: AppColors.surface2),
            errorWidget: (context, url, error) => Container(
              color: AppColors.surface2,
              child: const Icon(Icons.movie_outlined, size: 20),
            ),
          ),
        ),
        iconColor: widget.accentColor,
        collapsedIconColor: Colors.white54,
        children: [
          if (_isLoading)
            _buildLocalEpisodeSkeleton()
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Text(
                _error!,
                style: GoogleFonts.dmSans(
                    color: Colors.redAccent, fontSize: 13),
              ),
            )
          else if (_fullSeason == null || _fullSeason!.episodes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Text(
                'Episode details coming soon.',
                style: GoogleFonts.dmSans(
                    color: AppColors.textMuted, fontSize: 13),
              ),
            )
          else
            Column(
              children: [
                const SizedBox(height: 16),
                ..._fullSeason!.episodes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final ep = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(
                        bottom:
                            index == _fullSeason!.episodes.length - 1 ? 0 : 24),
                    child: EpisodeItem(
                      episode: ep,
                      seasonNumber: widget.season.seasonNumber,
                      movie: widget.movie,
                      accentColor: widget.accentColor,
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLocalEpisodeSkeleton() {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surface2,
      child: Column(
        children: List.generate(
          2,
          (index) => Container(
            height: 100,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EpisodeItem
// ─────────────────────────────────────────────────────────────────────────────

class EpisodeItem extends StatelessWidget {
  final Episode episode;
  final int seasonNumber;
  final Movie movie;
  final Color accentColor;

  const EpisodeItem({
    super.key,
    required this.episode,
    required this.seasonNumber,
    required this.movie,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: episode.stillPath,
                    width: 140,
                    height: 80,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: AppColors.surface2),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.surface2,
                      child: const Icon(Icons.play_circle_outline,
                          color: Colors.white30),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        episode.runtime,
                        style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${episode.episodeNumber}. ${episode.name}',
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          color: AppColors.ratingGold, size: 10),
                      const SizedBox(width: 4),
                      Text(
                        episode.rating.toStringAsFixed(1),
                        style: GoogleFonts.dmSans(
                          color: AppColors.ratingGold,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          episode.airDate.split('-').first,
                          style: GoogleFonts.dmSans(
                              color: AppColors.textMuted, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          episode.overview,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}