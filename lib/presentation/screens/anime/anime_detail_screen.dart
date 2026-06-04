import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:watch_track/core/utils/adaptive_theme_helper.dart';
import 'package:watch_track/presentation/widgets/free_streams_section.dart';
import 'package:watch_track/data/models/movie_model.dart';
import 'package:watch_track/back-end/api_service.dart';
import 'package:watch_track/core/providers/tracking_provider.dart';
import 'package:watch_track/presentation/widgets/watchlist_action_sheet.dart';
import 'package:watch_track/presentation/screens/anime/anime_home_screen.dart'; // For AnimeColors and AnimeMovieCard
import 'package:watch_track/presentation/screens/anime/anime_actor_detail_screen.dart';
import 'package:watch_track/data/models/user_title_model.dart';
import 'package:watch_track/features/soundtrack/presentation/widgets/songs_section.dart';
import 'package:watch_track/presentation/widgets/global_trailer_player.dart';

class AnimeDetailScreen extends StatefulWidget {
  final Movie movie;
  const AnimeDetailScreen({super.key, required this.movie});

  @override
  State<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends State<AnimeDetailScreen> {
  final ApiService _apiService = ApiService();
  Movie? _fullAnime;
  List<Movie> _similarAnime = [];
  bool _isLoading = true;
  bool _isLoadingSimilar = true;
  int _selectedTab = 0; // 0 = Details, 1 = Reviews, 2 = Soundtrack
  List<Review> _reviews = [];
  bool _isLoadingReviews = false;
  bool _isExpanded = false;

  bool _isTrailerMode = false;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails({bool forceRefresh = false}) async {
    _fetchAnimeDetails(forceRefresh: forceRefresh);
    _fetchSimilarAnime(forceRefresh: forceRefresh);
    _fetchReviews(forceRefresh: forceRefresh);
  }

  Future<void> _fetchAnimeDetails({bool forceRefresh = false}) async {
    final details = await _apiService.getMovieById(widget.movie.id, isMovie: false, forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _fullAnime = details;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchSimilarAnime({bool forceRefresh = false}) async {
    final similar = await _apiService.getSimilarContent(widget.movie.id, isMovie: false, forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _similarAnime = similar;
        _isLoadingSimilar = false;
      });
    }
  }

  Future<void> _fetchReviews({bool forceRefresh = false}) async {
    setState(() => _isLoadingReviews = true);
    final reviews = await _apiService.getReviews(widget.movie.id, isMovie: false, forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _reviews = reviews;
        _isLoadingReviews = false;
      });
    }
  }

  void _playTrailer(Movie anime) async {
    setState(() {
      _isTrailerMode = true;
    });
  }

  void _shareAnime(Movie anime) {
    final url = 'https://www.themoviedb.org/tv/${anime.id}';
    Share.share('🎬 Watching "${anime.title}" on Track-n-Tube!\n$url');
  }

  void _showWatchlistSheet(BuildContext context, Movie anime) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => WatchlistActionSheet(movie: anime),
    );
  }

  Future<void> _handleRefresh() async {
    await _loadDetails(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final anime = _fullAnime ?? widget.movie;

    return Scaffold(
      backgroundColor: AnimeColors.background,
      body: Stack(
        children: [
          _buildCinematicBackground(anime),
          RefreshIndicator(
            onRefresh: _handleRefresh,
            backgroundColor: AnimeColors.background,
            color: AnimeColors.actionRed,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                _buildSliverHeader(anime),
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AnimeColors.background,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),
                        _buildCinematicMetaGrid(anime),
                        const SizedBox(height: 40),
                        _buildTabs(),
                        const SizedBox(height: 32),
                        if (_selectedTab == 0) ...[
                          _buildSynopsis(anime),
                          const SizedBox(height: 32),
                          FreeStreamsSection(movie: anime),
                          const SizedBox(height: 32),
                          _buildUserRatingSection(anime),
                          const SizedBox(height: 48),
                          if (anime.cast.isNotEmpty) _buildCastSection(anime),
                          const SizedBox(height: 48),
                          _buildRecommendationsSection(),
                        ] else if (_selectedTab == 1) ...[
                          _buildReviewsTab(),
                        ] else ...[
                          _buildSoundtrackTab(anime),
                        ],
                        const SizedBox(height: 100),
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
          CachedNetworkImage(
            imageUrl: movie.backdropPath,
            fit: BoxFit.cover,
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              color: AnimeColors.background.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverHeader(Movie anime) {
    return SliverAppBar(
      expandedHeight: 400,
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.white,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Positioned.fill(
              child: Hero(
                tag: 'anime_${anime.id}',
                child: CachedNetworkImage(
                  imageUrl: anime.posterPath,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (_isTrailerMode)
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: GlobalTrailerPlayer(movie: widget.movie),
                ),
              ),
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
                    anime.title.toUpperCase(),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: anime.genres.take(3).map((g) => Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white30),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(g.toUpperCase(), style: GoogleFonts.dmSans(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  _buildActionButtons(anime),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCinematicMetaGrid(Movie anime) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildMetaItem('DURATION', anime.runtime.isNotEmpty ? anime.runtime : '--'),
        _buildMetaItem('RELEASE', anime.releaseDate.split('-').first),
        _buildMetaItem('RATING', anime.rating.toString()),
        _buildMetaItem('AGE', anime.ageRating.isNotEmpty ? anime.ageRating : 'NR'),
      ],
    );
  }

  Widget _buildMetaItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.dmSans(color: AnimeColors.textSecondary, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.dmSans(color: AnimeColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionButtons(Movie anime) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: () => _playTrailer(anime),
              style: ElevatedButton.styleFrom(
                backgroundColor: AnimeColors.actionRed,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                '▶  TRAILER',
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Consumer<TrackingProvider>(
          builder: (context, tracking, _) {
            final t = tracking.getTracking(int.tryParse(anime.id) ?? 0);
            final inWatchlist = t != null;
            return OutlinedButton(
              onPressed: () {
                if (inWatchlist) {
                  tracking.removeTracking(int.tryParse(anime.id) ?? 0);
                  HapticFeedback.lightImpact();
                } else {
                  _showWatchlistSheet(context, anime);
                }
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white),
                foregroundColor: Colors.white,
                backgroundColor: inWatchlist ? Colors.white24 : Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Icon(inWatchlist ? Icons.bookmark_rounded : Icons.bookmark_add_outlined, size: 20),
            );
          },
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => _shareAnime(anime),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.white),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Icon(Icons.ios_share_rounded, size: 20),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildTabItem('DETAILS', 0),
        _buildTabItem('REVIEWS', 1),
        _buildTabItem('SOUNDTRACK', 2),
      ],
    );
  }

  Widget _buildTabItem(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: isSelected ? AnimeColors.actionRed : AnimeColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 6),
              height: 3,
              width: 30,
              decoration: BoxDecoration(
                color: AnimeColors.actionRed,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSynopsis(Movie anime) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SYNOPSIS',
          style: GoogleFonts.dmSans(
            color: AnimeColors.textSecondary,
            fontSize: 10,
            letterSpacing: 3,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          anime.overview,
          maxLines: _isExpanded ? null : 4,
          style: GoogleFonts.dmSans(
            color: AnimeColors.textPrimary,
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
              color: AnimeColors.actionRed,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserRatingSection(Movie anime) {
    return Consumer<TrackingProvider>(
      builder: (context, tracking, _) {
        final t = tracking.getTracking(int.tryParse(anime.id) ?? 0);
        final canRate = t != null;
        final currentRating = t?.userRating ?? 0.0;

        if (!canRate) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AnimeColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AnimeColors.border, width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, color: AnimeColors.textSecondary, size: 16),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add this anime to your library to unlock ratings.',
                    style: GoogleFonts.dmSans(color: AnimeColors.textSecondary, fontSize: 11),
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
                color: AnimeColors.textSecondary,
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
                    tracking.rateMovie(anime, starValue);
                    HapticFeedback.lightImpact();
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Icon(
                      isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isSelected ? AnimeColors.actionRed : AnimeColors.textSecondary,
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

  Widget _buildCastSection(Movie anime) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VOICE CAST',
          style: GoogleFonts.dmSans(
            color: AnimeColors.textSecondary,
            fontSize: 10,
            letterSpacing: 3,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: anime.cast.length,
            itemBuilder: (context, index) {
              final actor = anime.cast[index];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (ctx) => AnimeActorDetailScreen(actorId: actor.id)),
                ),
                child: Container(
                  width: 90,
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AnimeColors.surface2,
                        backgroundImage: actor.profilePath.isNotEmpty
                            ? CachedNetworkImageProvider(actor.profilePath)
                            : null,
                        child: actor.profilePath.isEmpty
                            ? const Icon(Icons.person, color: AnimeColors.textSecondary, size: 40)
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        actor.name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: AnimeColors.textPrimary),
                      ),
                      Text(
                        actor.character,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(fontSize: 9, color: AnimeColors.textSecondary),
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

  Widget _buildRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RELATED ANIME',
          style: GoogleFonts.dmSans(
            color: AnimeColors.textSecondary,
            fontSize: 10,
            letterSpacing: 3,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: _isLoadingSimilar
              ? const Center(child: CircularProgressIndicator(color: AnimeColors.actionRed))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _similarAnime.length,
                  itemBuilder: (context, index) {
                    final m = _similarAnime[index];
                    return AnimeMovieCard(
                      movie: m,
                      heroTag: 'similar_${m.id}',
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (ctx) => AnimeDetailScreen(movie: m)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReviewsTab() {
    if (_isLoadingReviews) return const Center(child: CircularProgressIndicator(color: AnimeColors.actionRed));
    if (_reviews.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'NO REVIEWS YET',
            style: GoogleFonts.dmSans(color: AnimeColors.textSecondary, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
    return Column(
      children: _reviews.map((r) => Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AnimeColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AnimeColors.accent,
                  child: Text(r.author[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14)),
                ),
                const SizedBox(width: 12),
                Text(r.author.toUpperCase(), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              r.content,
              style: GoogleFonts.dmSans(fontSize: 14, height: 1.6, color: AnimeColors.textPrimary),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildSoundtrackTab(Movie anime) {
    return Container(
      constraints: const BoxConstraints(minHeight: 400),
      child: SongsSection(mediaId: anime.id, title: anime.title, isAnime: true, isMovie: false),
    );
  }
}
