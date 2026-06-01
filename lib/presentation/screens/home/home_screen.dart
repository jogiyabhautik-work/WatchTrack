import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watch_track/back-end/api_service.dart';
import 'package:watch_track/core/constants/app_colors.dart';

import 'package:watch_track/data/models/movie_model.dart';
import 'package:watch_track/presentation/widgets/movie_card.dart';
import 'package:watch_track/presentation/screens/detail/detail_screen.dart';
import 'package:watch_track/presentation/screens/genre/genre_screen.dart';
import 'package:watch_track/core/providers/user_data_provider.dart';
import 'package:watch_track/core/providers/recommendation_provider.dart';
import 'package:watch_track/core/utils/adaptive_theme_helper.dart';
import 'package:watch_track/core/services/global_youtube_service.dart';
import 'package:watch_track/core/appwrite_client.dart';
import 'package:watch_track/core/providers/tracking_provider.dart';
import 'package:watch_track/presentation/screens/home/see_all_screen.dart';
import 'package:watch_track/presentation/screens/profile/profile_screen.dart';
import 'package:watch_track/presentation/screens/watchlist/watchlist_screen.dart';
import 'package:watch_track/presentation/widgets/watchlist_action_sheet.dart';
import 'package:watch_track/presentation/widgets/binge_planner.dart';
import 'package:watch_track/presentation/screens/anime/anime_home_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _error;
  bool _isNavigating = false;
  String _selectedGenre = 'Action';

  final List<String> _genres = [
    'Action', 'Adventure', 'Animation', 'Comedy', 'Crime', 
    'Documentary', 'Drama', 'Fantasy', 'Horror', 'Mystery', 
    'Romance', 'Sci-Fi', 'Thriller', 'Western'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool isRefresh = false}) async {
    final recProvider = context.read<RecommendationProvider>();
    final userData = context.read<UserDataProvider>();
    final tracking = context.read<TrackingProvider>();
    
    await recProvider.refreshRecommendations(userData, tracking, force: isRefresh);
  }

  Future<void> _safeNavigate(Widget screen) async {
    if (_isNavigating) return;
    _isNavigating = true;
    try {
      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => screen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: animation.drive(Tween(begin: 0.95, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic))),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } finally {
      _isNavigating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading 
          ? _buildGlobalSkeleton()
          : Stack(
              children: [
                // Background gradient
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.6, -0.8),
                        radius: 1.2,
                        colors: [
                          AppColors.primary.withOpacity(0.12),
                          AppColors.background,
                        ],
                      ),
                    ),
                  ),
                ),
                
                RefreshIndicator(
                  onRefresh: () async {
                    await _loadData(isRefresh: true);
                  },
                  child: Consumer2<UserDataProvider, RecommendationProvider>(
                          builder: (context, userData, recProvider, child) {
                            // Removed refreshRecommendations from builder to prevent build loops
    
                            if (recProvider.isLoading && recProvider.trendingNow.isEmpty) {
                              return _buildGlobalSkeleton();
                            }

                        return SingleChildScrollView(
                          key: const PageStorageKey('home_scroll'),
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          padding: const EdgeInsets.only(bottom: 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SafeArea(
                                bottom: false,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'WATCH TRACK',
                                        style: GoogleFonts.playfairDisplay(
                                          color: AppColors.primary,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => _safeNavigate(const ProfileScreen()),
                                        behavior: HitTestBehavior.opaque,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Consumer<UserDataProvider>(
                                            builder: (context, userData, _) {
                                              final pfp = userData.pfpUrl;
                                              if (pfp != null && pfp.isNotEmpty) {
                                                return Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: AppColors.primary, width: 1.5),
                                                    image: DecorationImage(
                                                      image: CachedNetworkImageProvider(pfp),
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                );
                                              }
                                              return const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 28);
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // SECTION A: Hero Carousel (Trending)
                              if (recProvider.trendingNow.isNotEmpty) TrendingHeroCarousel(
                                movies: recProvider.trendingNow.take(5).toList(),
                                onPlayTrailer: _playTrailer,
                              ) else _buildCarouselSkeleton(),

                              const SizedBox(height: 32),

                              // SECTION B: Category Chips
                              _buildCategorySection(),

                              const SizedBox(height: 40),

                              // SECTION: QUICK DISCOVERY
                              _buildLuxuryDiscoverySection(),

                              const SizedBox(height: 40),

                              // SECTION: SPOTLIGHT (NEW)
                              if (recProvider.topPicks.isNotEmpty)
                                _buildSpotlightHero(recProvider.topPicks.first),

                              const SizedBox(height: 40),

                              // SECTION: DAILY PICKS (NEW)
                              if (recProvider.topPicks.length > 3)
                                _buildDailyPicksSection(recProvider.topPicks.skip(1).take(3).toList()),

                              const SizedBox(height: 40),

                              // SECTION: ANIME WORLD (Dedicated Section)
                              _buildAnimeEntryCard(),

                              const SizedBox(height: 40),

                              // SECTION: CONTINUE WATCHING
                              if (recProvider.continueWatching.isNotEmpty) ...[
                                _buildHorizontalSection(
                                  'Continue Watching', 
                                  recProvider.continueWatching, 
                                  'continue',
                                  onSeeAll: () => _safeNavigate(SeeAllScreen(
                                    title: 'Continue Watching',
                                    movies: recProvider.continueWatching,
                                    tagPrefix: 'continue',
                                  )),
                                ),
                                const SizedBox(height: 40),
                              ],


                              // SECTION: TOP PICKS
                              if (recProvider.topPicks.isNotEmpty) ...[
                                _buildHorizontalSection(
                                  'Top Picks For You', 
                                  recProvider.topPicks, 
                                  'top_picks',
                                  onSeeAll: () => _safeNavigate(SeeAllScreen(
                                    title: 'Top Picks For You',
                                    movies: recProvider.topPicks,
                                    tagPrefix: 'top_picks',
                                  )),
                                ),
                                const SizedBox(height: 40),
                              ],


                              // SECTION: BECAUSE YOU WATCHED
                              if (recProvider.becauseYouWatched.isNotEmpty) ...[
                                _buildHorizontalSection(
                                  'Because You Watched', 
                                  recProvider.becauseYouWatched, 
                                  'because_watched',
                                  onSeeAll: () => _safeNavigate(SeeAllScreen(
                                    title: 'Because You Watched',
                                    movies: recProvider.becauseYouWatched,
                                    tagPrefix: 'because_watched',
                                  )),
                                ),
                                const SizedBox(height: 40),
                              ],


                              // SECTION: HIDDEN GEMS
                              if (recProvider.hiddenGems.isNotEmpty) ...[
                                _buildHorizontalSection(
                                  'Hidden Gems', 
                                  recProvider.hiddenGems, 
                                  'hidden_gems',
                                  onSeeAll: () => _safeNavigate(SeeAllScreen(
                                    title: 'Hidden Gems',
                                    movies: recProvider.hiddenGems,
                                    tagPrefix: 'hidden_gems',
                                  )),
                                ),
                                const SizedBox(height: 40),
                              ],


                              // SECTION: TRENDING NOW
                              if (recProvider.trendingNow.isNotEmpty) ...[
                                _buildHorizontalSection(
                                  'Trending Now', 
                                  recProvider.trendingNow, 
                                  'trending_now',
                                  onSeeAll: () => _safeNavigate(SeeAllScreen(
                                    title: 'Trending Now',
                                    movies: recProvider.trendingNow,
                                    tagPrefix: 'trending_now',
                                  )),
                                ),
                              ],

                            ],
                          ),
                        );
                      },
                    ),
                ),
              ],
            ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.primary, size: 48),
          const SizedBox(height: 16),
          Text(_error!, style: GoogleFonts.dmSans(color: Colors.white)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _loadData(),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'BROWSE BY GENRE',
            style: GoogleFonts.dmSans(
              color: AppColors.textMuted,
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _genres.length,
            itemBuilder: (context, index) {
              final genre = _genres[index];
              final isSelected = _selectedGenre == genre;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: FilterChip(
                  label: Text(genre),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (_selectedGenre != genre) {
                      setState(() => _selectedGenre = genre);
                      _safeNavigate(GenreScreen(genreName: genre));
                    }
                  },
                  labelStyle: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.primary.withOpacity(0.15),
                  checkmarkColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.borderDefault,
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

  Widget _buildLuxuryDiscoverySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'FOR YOUR CONSIDERATION',
            style: GoogleFonts.dmSans(
              color: AppColors.textMuted,
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildLuxuryMoodCard('MOOD PICKER', 'FEELING SCARY?', Colors.orange, Icons.waves, _showMoodPicker),
              _buildLuxuryMoodCard('BINGE PLAN', 'WEEKEND GOALS', Colors.purple, Icons.event_note, _showBingePlanner),
              _buildLuxuryMoodCard('SURPRISE', 'ROLL THE DICE', Colors.blue, Icons.casino, _pickRandomMovie),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLuxuryMoodCard(String title, String sub, Color color, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const Spacer(),
            Text(title, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
            Text(sub, style: GoogleFonts.dmSans(fontSize: 8, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyPicksSection(List<Movie> movies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Text(
                'THE DAILY THREE',
                style: GoogleFonts.dmSans(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'EDITOR\'S CHOICE',
                  style: GoogleFonts.dmSans(color: AppColors.primary, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              final heroTag = 'daily_${movie.id}';
              return GestureDetector(
                onTap: () => _safeNavigate(DetailScreen(movie: movie, heroTag: heroTag)),
                child: Container(
                  width: 300,
                  margin: const EdgeInsets.only(right: 16),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Hero(
                            tag: heroTag,
                            child: CachedNetworkImage(
                              imageUrl: movie.backdropPath,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              movie.title,
                              style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              movie.genres.join(' · '),
                              style: GoogleFonts.dmSans(color: Colors.white60, fontSize: 10),
                            ),
                          ],
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

  Widget _buildSpotlightHero(Movie movie) {
    final heroTag = 'spotlight_${movie.id}';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 220,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Hero(
                tag: heroTag,
                child: CachedNetworkImage(
                  imageUrl: movie.backdropPath,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'SPOTLIGHT',
                    style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 180,
                  child: Text(
                    movie.title.toUpperCase(),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _safeNavigate(DetailScreen(movie: movie, heroTag: heroTag)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text('VIEW NOW', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimeEntryCard() {
    return GestureDetector(
      onTap: () => _safeNavigate(const AnimeHomeScreen()),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              offset: const Offset(6, 6),
              blurRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Stack(
            children: [
              // 1. Background Speed Lines
              Positioned.fill(
                child: CustomPaint(
                  painter: MangaSpeedLinesPainter(),
                ),
              ),

              // 2. Slanted Black Section
              Positioned.fill(
                child: ClipPath(
                  clipper: AnimeSlantClipper(),
                  child: Container(color: Colors.black),
                ),
              ),

              // 3. Large Japanese Text (Background-ish)
              Positioned(
                right: 20,
                top: 40,
                child: Transform.rotate(
                  angle: 0.05,
                  child: Text(
                    'アニメ',
                    style: GoogleFonts.stixTwoText(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 80,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -5,
                    ),
                  ),
                ),
              ),

              // 4. Content
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'DEDICATED SECTION',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'EXPLORE\nANIME WORLD',
                      style: GoogleFonts.stixTwoText(
                        color: Colors.black,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 0.95,
                        shadows: [
                          const Shadow(
                            color: Colors.white,
                            offset: Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'ENTER NOW',
                          style: GoogleFonts.dmSans(
                            color: Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 18),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoveryCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderDefault, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoodPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final moods = [
          {'name': 'Scary', 'genre': 'Horror', 'icon': '😱'},
          {'name': 'Happy', 'genre': 'Comedy', 'icon': '😂'},
          {'name': 'Epic', 'genre': 'Adventure', 'icon': '🌋'},
          {'name': 'Dark', 'genre': 'Thriller', 'icon': '🔪'},
          {'name': 'Romantic', 'genre': 'Romance', 'icon': '❤️'},
          {'name': 'Mind-bending', 'genre': 'Sci-Fi', 'icon': '🌀'},
        ];
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'HOW ARE YOU FEELING?',
                style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: moods.length,
                itemBuilder: (context, index) {
                  final mood = moods[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _safeNavigate(GenreScreen(genreName: mood['genre']!));
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderDefault, width: 0.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(mood['icon']!, style: const TextStyle(fontSize: 24)),
                          const SizedBox(height: 8),
                          Text(
                            mood['name']!,
                            style: GoogleFonts.dmSans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _pickRandomMovie() async {
    final randomGenre = _genres[DateTime.now().second % _genres.length];
    final movies = await _apiService.getMoviesByGenre(randomGenre);
    if (movies.isNotEmpty && mounted) {
      final randomMovie = movies[DateTime.now().millisecond % movies.length];
      _safeNavigate(DetailScreen(movie: randomMovie, heroTag: 'random_${randomMovie.id}'));
    }
  }

  void _showBingePlanner() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const Padding(
        padding: EdgeInsets.only(top: 100),
        child: BingePlannerWidget(),
      ),
    );
  }

  Widget _buildHorizontalSection(String title, List<Movie> movies, String tagPrefix, {VoidCallback? onSeeAll}) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onSeeAll,
                child: Text(
                  'See all',
                  style: GoogleFonts.dmSans(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              return MovieCard(
                posterUrl: movie.posterPath,
                title: movie.title,
                rating: movie.rating,
                heroTag: '${tagPrefix}_${movie.id}',
                onTap: () => _safeNavigate(DetailScreen(movie: movie, heroTag: '${tagPrefix}_${movie.id}')),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGlobalSkeleton() {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surface2,
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildCarouselSkeleton(),
            const SizedBox(height: 32),
            _buildListSkeleton(40, 100),
            const SizedBox(height: 40),
            _buildListSkeleton(80, 170),
            const SizedBox(height: 40),
            _buildListSkeleton(180, 120),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselSkeleton() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.52,
      color: AppColors.surface,
    );
  }

  Widget _buildListSkeleton(double height, double width) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(width: 100, height: 10, color: Colors.white),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: height,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            itemBuilder: (context, index) => Container(
              width: width,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  void _playTrailer(Movie movie) async {
    final trailers = await GlobalYouTubeService().getTrailers(
      tmdbId: movie.id,
      isMovie: movie.isMovie,
      title: movie.title,
      year: movie.releaseDate.isNotEmpty ? movie.releaseDate.substring(0, 4) : null,
    );
    if (trailers.isNotEmpty) {
      final trailerKey = trailers.first.id;
      final url = Uri.parse('https://www.youtube.com/watch?v=$trailerKey');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    }
  }
}

class AnimeSlantClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width * 0.5, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width * 0.55, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class MangaSpeedLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.03)
      ..strokeWidth = 1.5;

    for (int i = 0; i < 20; i++) {
      canvas.drawLine(
        Offset(i * 30.0, 0),
        Offset(i * 30.0 - 50, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class TrendingHeroCarousel extends StatefulWidget {
  final List<Movie> movies;
  final Function(Movie) onPlayTrailer;

  const TrendingHeroCarousel({
    super.key, 
    required this.movies, 
    required this.onPlayTrailer
  });

  @override
  State<TrendingHeroCarousel> createState() => _TrendingHeroCarouselState();
}

class _TrendingHeroCarouselState extends State<TrendingHeroCarousel> {
  final PageController _pageController = PageController();
  int _currentHeroPage = 0;
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    _startCarouselTimer();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        final nextPage = (_currentHeroPage + 1) % widget.movies.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return SizedBox(
      height: screenHeight * 0.52,
      width: double.infinity,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _currentHeroPage = index);
          _startCarouselTimer();
        },
        itemCount: widget.movies.length,
        itemBuilder: (context, index) {
          final movie = widget.movies[index];
          return _buildHeroItem(movie, index + 1);
        },
      ),
    );
  }

  Widget _buildHeroItem(Movie movie, int rank) {
    return GestureDetector(
      onTap: () {
        if (_pageController.position.isScrollingNotifier.value) return; // Prevent tap while scrolling
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DetailScreen(movie: movie)),
        );
      },
      child: Stack(
        children: [
          // Backdrop Image
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: movie.backdropPath,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: AppColors.surface),
              errorWidget: (context, url, error) => Container(color: AppColors.surface),
            ),
          ),
          
          // Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.3, 1.0],
                  colors: [
                    Colors.transparent,
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
  
          // Content
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'TRENDING #$rank',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: AppColors.ratingGold, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          movie.rating.toStringAsFixed(1),
                          style: GoogleFonts.dmSans(
                            color: AppColors.ratingGold,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  movie.genres.take(2).join(' · ').toUpperCase(),
                  style: GoogleFonts.dmSans(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  movie.title,
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  movie.overview,
                  style: GoogleFonts.dmSans(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () => widget.onPlayTrailer(movie),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            'PLAY TRAILER',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Consumer<TrackingProvider>(
                        builder: (context, tracking, child) {
                          final isInWatchlist = tracking.getTracking(int.tryParse(movie.id) ?? 0) != null;
                          return SizedBox(
                            height: 40,
                            child: OutlinedButton(
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => WatchlistActionSheet(movie: movie),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.borderDefault),
                                foregroundColor: AppColors.textSecondary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: EdgeInsets.zero,
                              ),
                              child: Text(
                                isInWatchlist ? 'IN WATCHLIST' : '+ WATCHLIST',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
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
    );
  }
}
