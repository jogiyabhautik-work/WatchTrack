import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/data/models/movie_model.dart';
import 'package:watch_track/back-end/api_service.dart';
import 'package:watch_track/core/providers/tracking_provider.dart';
import 'package:watch_track/presentation/widgets/watchlist_action_sheet.dart';
import 'package:watch_track/presentation/widgets/movie_card.dart';
import 'package:watch_track/presentation/screens/anime/anime_home_screen.dart';
import 'package:watch_track/presentation/screens/anime/anime_actor_detail_screen.dart';
import 'package:watch_track/data/models/user_title_model.dart';

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
  int _selectedTab = 0; // 0 = Details, 1 = Reviews
  List<Review> _reviews = [];
  bool _isLoadingReviews = false;

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
    final trailerKey = await _apiService.getMovieTrailer(anime.id, isMovie: false);
    if (trailerKey != null) {
      final url = Uri.parse('https://www.youtube.com/watch?v=$trailerKey');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _shareAnime(Movie anime) {
    final url = 'https://www.themoviedb.org/tv/${anime.id}';
    Share.share('🎬 Watching "${anime.title}" on WatchTrack!\n$url');
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
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        backgroundColor: AnimeColors.background,
        color: AnimeColors.accent,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            _buildSliverHeader(anime),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildMetaRow(anime),
                    const SizedBox(height: 24),
                    _buildTitleRow(anime),
                    const SizedBox(height: 24),
                    _buildActionButtons(anime),
                    const SizedBox(height: 32),
                    _buildMangaPanel(anime),
                    const SizedBox(height: 32),
                    _buildTabs(),
                    const SizedBox(height: 24),
                    if (_selectedTab == 0) ...[
                      _buildSynopsis(anime),
                      const SizedBox(height: 32),
                      _buildUserRatingSection(anime),
                      const SizedBox(height: 32),
                      if (anime.cast.isNotEmpty) _buildCastSection(anime),
                      const SizedBox(height: 32),
                      _buildRecommendationsSection(),
                    ] else ...[
                      _buildReviewsTab(),
                    ],
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(Movie anime) {
    return Row(
      children: [
        _buildScoreBadge('MAL', anime.rating.toStringAsFixed(1), Colors.blue),
        const SizedBox(width: 12),
        _buildScoreBadge('TV', anime.ageRating.isNotEmpty ? anime.ageRating : '13+', Colors.red),
        const Spacer(),
        Text(
          '${anime.runtime} / EP',
          style: GoogleFonts.dmSans(
            color: AnimeColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreBadge(String label, String score, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: GoogleFonts.dmSans(color: color, fontSize: 8, fontWeight: FontWeight.w900)),
          const SizedBox(width: 4),
          Text(score, style: GoogleFonts.dmSans(color: AnimeColors.textPrimary, fontSize: 9, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Movie anime) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => _playTrailer(anime),
            style: ElevatedButton.styleFrom(
              backgroundColor: AnimeColors.accent,
              foregroundColor: AnimeColors.background,
              elevation: 0,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              side: const BorderSide(color: AnimeColors.border, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow_rounded, size: 24),
                const SizedBox(width: 8),
                Text(
                  'WATCH TRAILER',
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
              ],
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
                  final t = tracking.getTracking(int.tryParse(anime.id) ?? 0);
                  final inWatchlist = t != null;
                  return GestureDetector(
                    onTap: () {
                      if (inWatchlist) {
                        tracking.removeTracking(int.tryParse(anime.id) ?? 0);
                        HapticFeedback.lightImpact();
                      } else {
                        _showWatchlistSheet(context, anime);
                      }
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: inWatchlist ? AnimeColors.accent : AnimeColors.background,
                        border: Border.all(color: AnimeColors.border, width: 2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            inWatchlist ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
                            color: inWatchlist ? AnimeColors.background : AnimeColors.accent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            inWatchlist ? 'SAVED' : 'ADD TO LIST',
                            style: GoogleFonts.dmSans(
                              color: inWatchlist ? AnimeColors.background : AnimeColors.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            _buildIconButton(Icons.favorite_border_rounded, () {}),
            const SizedBox(width: 12),
            _buildIconButton(Icons.ios_share_rounded, () => _shareAnime(anime)),
          ],
        ),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          border: Border.all(color: AnimeColors.border, width: 2),
        ),
        child: Icon(icon, color: AnimeColors.accent, size: 20),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AnimeColors.border, width: 2)),
      ),
      child: Row(
        children: [
          _buildTabItem('OVERVIEW', 0),
          _buildTabItem('REVIEWS', 1),
        ],
      ),
    );
  }

  Widget _buildTabItem(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AnimeColors.accent : Colors.transparent,
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            color: isSelected ? AnimeColors.background : AnimeColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildUserRatingSection(Movie anime) {
    return Consumer<TrackingProvider>(
      builder: (context, tracking, _) {
        final t = tracking.getTracking(int.tryParse(anime.id) ?? 0);
        final currentRating = t?.userRating ?? 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RATE THIS ANIME',
              style: GoogleFonts.dmSans(
                color: AnimeColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: List.generate(5, (index) {
                final starValue = (index + 1) * 2.0;
                final isSelected = currentRating >= starValue;
                return GestureDetector(
                  onTap: () {
                    if (t != null) {
                      tracking.rateMovie(anime, starValue);
                      HapticFeedback.mediumImpact();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Add to list first to rate!')),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Icon(
                      isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isSelected ? Colors.orange : AnimeColors.textSecondary,
                      size: 32,
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

  Widget _buildRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MORE LIKE THIS',
          style: GoogleFonts.dmSans(
            color: AnimeColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 20),
        const SizedBox(height: 8),
        SizedBox(
          height: 250,
          child: _isLoadingSimilar
              ? const Center(child: CircularProgressIndicator(color: AnimeColors.accent))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _similarAnime.length,
                  itemBuilder: (context, index) {
                    final m = _similarAnime[index];
                    return GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (ctx) => AnimeDetailScreen(movie: m)),
                      ),
                      child: Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: AnimeColors.border, width: 2),
                                  boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: m.posterPath,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              m.title.toUpperCase(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.stixTwoText(
                                color: AnimeColors.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
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

  Widget _buildReviewsTab() {
    if (_isLoadingReviews) {
      return const Center(child: CircularProgressIndicator(color: AnimeColors.accent));
    }
    if (_reviews.isEmpty) {
      return Center(
        child: Text(
          'NO REVIEWS YET',
          style: GoogleFonts.dmSans(color: AnimeColors.textSecondary, fontWeight: FontWeight.w900),
        ),
      );
    }
    return Column(
      children: _reviews.map((r) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AnimeColors.border, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AnimeColors.accent,
                  child: Text(r.author[0], style: const TextStyle(color: AnimeColors.background, fontSize: 10)),
                ),
                const SizedBox(width: 8),
                Text(r.author.toUpperCase(), style: GoogleFonts.dmSans(fontWeight: FontWeight.w900, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              r.content,
              style: GoogleFonts.dmSans(fontSize: 13, height: 1.5),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildSliverHeader(Movie anime) {
    return SliverAppBar(
      expandedHeight: 400,
      backgroundColor: AnimeColors.background,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: AnimeColors.accent),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: anime.backdropPath,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  color: AnimeColors.surface,
                  child: const Icon(Icons.movie_outlined, color: AnimeColors.accent, size: 50),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AnimeColors.background.withOpacity(0.5),
                      AnimeColors.background,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleRow(Movie anime) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: AnimeColors.border, width: 1.5),
              ),
              child: Text(
                'SERIES',
                style: GoogleFonts.dmSans(
                  color: AnimeColors.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              anime.releaseDate.split('-').first,
              style: GoogleFonts.dmSans(
                color: AnimeColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          anime.title.toUpperCase(),
          style: GoogleFonts.stixTwoText(
            color: AnimeColors.textPrimary,
            fontSize: 40,
            fontWeight: FontWeight.w900,
            height: 0.9,
          ),
        ),
      ],
    );
  }

  Widget _buildMangaPanel(Movie anime) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border.all(color: AnimeColors.border, width: 3),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: AnimeColors.surface,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      anime.rating.toStringAsFixed(1),
                      style: GoogleFonts.stixTwoText(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'SCORE',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(width: 3, color: AnimeColors.border),
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPanelStat('STATUS', 'AIRING'),
                    const Spacer(),
                    _buildPanelStat('GENRES', anime.genres.take(2).join(', ').toUpperCase()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: AnimeColors.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.stixTwoText(
            color: AnimeColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildSynopsis(Movie anime) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SYNOPSIS',
          style: GoogleFonts.dmSans(
            color: AnimeColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: AnimeColors.border, width: 1.5),
          ),
          child: Text(
            anime.overview,
            style: GoogleFonts.dmSans(
              color: AnimeColors.textPrimary,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCastSection(Movie anime) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VOICE CAST',
          style: GoogleFonts.dmSans(
            color: AnimeColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: anime.cast.length,
            itemBuilder: (context, index) {
              final actor = anime.cast[index];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => AnimeActorDetailScreen(actorId: actor.id),
                  ),
                ),
                child: Container(
                  width: 90,
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: AnimeColors.border, width: 2),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: actor.profilePath,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.person,
                              color: AnimeColors.accent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        actor.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: GoogleFonts.dmSans(
                          color: AnimeColors.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
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
}
