import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:watch_track/data/models/movie_model.dart';
import 'package:watch_track/back-end/api_service.dart';
import 'package:watch_track/core/providers/recommendation_provider.dart';
import 'package:watch_track/core/providers/user_data_provider.dart';
import 'package:watch_track/core/providers/tracking_provider.dart';
import 'package:watch_track/presentation/screens/anime/anime_detail_screen.dart';
import 'package:watch_track/presentation/screens/search/search_screen.dart';
import 'package:watch_track/presentation/widgets/movie_card.dart';
import 'package:watch_track/presentation/screens/home/see_all_screen.dart';

class AnimeColors {
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF8F8F8);
  static const Color surface2 = Color(0xFFE0E0E0);
  static const Color accent = Color(0xFF000000);
  static const Color actionRed = Color(0xFFFF3D00);
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF444444);
  static const Color border = Color(0xFF000000);
  static const Color screentone = Color(0x1A000000);
}

class AnimeHomeScreen extends StatefulWidget {
  const AnimeHomeScreen({super.key});

  @override
  State<AnimeHomeScreen> createState() => _AnimeHomeScreenState();
}

class _AnimeHomeScreenState extends State<AnimeHomeScreen> {
  final ApiService _apiService = ApiService();
  
  late Future<List<Movie>> _trendingAnime;
  late Future<List<Movie>> _topRatedAnime;
  late Future<List<Movie>> _seasonalAnime;

  String? _selectedStudio;
  
  final Map<String, int> _studios = {
    'MAPPA': 104085,
    'Ufotable': 21908,
    'Madhouse': 11,
    'A-1 Pictures': 7169,
    'WIT Studio': 22003,
  };

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData({bool forceRefresh = false}) {
    _trendingAnime = _apiService.getTrendingAnime(forceRefresh: forceRefresh);
    _topRatedAnime = _apiService.getAnimeByCategory('Top Rated', forceRefresh: forceRefresh);
    _seasonalAnime = _apiService.getAnimeByCategory('Seasonal', forceRefresh: forceRefresh);
    
    final recProvider = context.read<RecommendationProvider>();
    final userData = context.read<UserDataProvider>();
    final tracking = context.read<TrackingProvider>();
    recProvider.refreshRecommendations(userData, tracking, force: forceRefresh);
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _refreshData(forceRefresh: true);
      if (_selectedStudio != null) {
        _trendingAnime = _apiService.getAnimeByStudio(_studios[_selectedStudio]!, forceRefresh: true);
      }
    });
  }

  void _safeNavigate(Widget screen) {
    Navigator.push(
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AnimeColors.background,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _handleRefresh,
            backgroundColor: AnimeColors.background,
            color: AnimeColors.actionRed,
            child: Consumer<RecommendationProvider>(
              builder: (context, recProvider, _) {
                final animeContinue = recProvider.continueWatching.where((m) => !m.isMovie).toList();
                
                return SingleChildScrollView(
                  key: const PageStorageKey('anime_home_scroll'),
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
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back_ios_new, color: AnimeColors.accent, size: 20),
                                    onPressed: () => Navigator.pop(context),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'ANIME / アニメ',
                                    style: GoogleFonts.stixTwoText(
                                      color: AnimeColors.textPrimary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context, 
                                  MaterialPageRoute(builder: (context) => const SearchScreen(initialFilter: 'Anime'))
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AnimeColors.border, width: 2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.search, color: AnimeColors.accent, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Hero Carousel (Trending)
                      FutureBuilder<List<Movie>>(
                        future: _trendingAnime,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox(height: 400, child: Center(child: CircularProgressIndicator(color: AnimeColors.actionRed)));
                          return AnimeTrendingHeroCarousel(movies: snapshot.data!.take(5).toList());
                        }
                      ),

                      const SizedBox(height: 32),

                      // Studios filter
                      _buildStudiosSection(),
                      const SizedBox(height: 40),

                      // Trending Now
                      FutureBuilder<List<Movie>>(
                        future: _trendingAnime,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          return _buildHorizontalSection('Trending Now', snapshot.data!, 'anime_trending');
                        }
                      ),
                      const SizedBox(height: 40),

                      // Continue Watching (Anime only)
                      if (animeContinue.isNotEmpty) ...[
                        _buildHorizontalSection('Continue Reading', animeContinue, 'anime_continue'),
                        const SizedBox(height: 40),
                      ],

                      // Seasonal
                      FutureBuilder<List<Movie>>(
                        future: _seasonalAnime,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          return _buildHorizontalSection('Seasonal Chronicles', snapshot.data!, 'anime_seasonal');
                        }
                      ),
                      const SizedBox(height: 40),

                      // Top Rated
                      FutureBuilder<List<Movie>>(
                        future: _topRatedAnime,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          return _buildHorizontalSection('Legendary Scrolls', snapshot.data!, 'anime_top');
                        }
                      ),
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

  Widget _buildStudiosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'BROWSE BY STUDIO',
            style: GoogleFonts.dmSans(
              color: AnimeColors.textSecondary,
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
            itemCount: _studios.keys.length,
            itemBuilder: (context, index) {
              final studio = _studios.keys.elementAt(index);
              final isSelected = _selectedStudio == studio;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: FilterChip(
                  label: Text(studio),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedStudio = selected ? studio : null;
                      if (_selectedStudio != null) {
                        _trendingAnime = _apiService.getAnimeByStudio(_studios[_selectedStudio]!, forceRefresh: false);
                      } else {
                        _trendingAnime = _apiService.getTrendingAnime(forceRefresh: false);
                      }
                    });
                  },
                  labelStyle: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: isSelected ? AnimeColors.background : AnimeColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: AnimeColors.surface,
                  selectedColor: AnimeColors.actionRed,
                  checkmarkColor: AnimeColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? AnimeColors.actionRed : AnimeColors.border,
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

  Widget _buildHorizontalSection(String title, List<Movie> movies, String tagPrefix) {
    if (movies.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.stixTwoText(
                  color: AnimeColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              GestureDetector(
                onTap: () => _safeNavigate(SeeAllScreen(
                  title: title,
                  movies: movies,
                  tagPrefix: tagPrefix,
                )),
                child: Row(
                  children: [
                    Text(
                      'SEE ALL',
                      style: GoogleFonts.dmSans(
                        color: AnimeColors.actionRed,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: AnimeColors.actionRed, size: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              return AnimeMovieCard(
                movie: movie,
                heroTag: '${tagPrefix}_${movie.id}',
                onTap: () => _safeNavigate(AnimeDetailScreen(movie: movie)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class AnimeMovieCard extends StatelessWidget {
  final Movie movie;
  final String heroTag;
  final VoidCallback onTap;

  const AnimeMovieCard({
    super.key,
    required this.movie,
    required this.heroTag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              Positioned.fill(
                child: Hero(
                  tag: heroTag,
                  child: CachedNetworkImage(
                    imageUrl: movie.posterPath,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: AnimeColors.surface2),
                    errorWidget: (context, url, error) => Container(
                      color: AnimeColors.surface2,
                      child: const Center(child: Icon(Icons.movie_outlined, color: AnimeColors.textSecondary)),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.5, 1.0],
                      colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, color: AnimeColors.actionRed, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          movie.rating.toStringAsFixed(1),
                          style: GoogleFonts.dmSans(
                            color: AnimeColors.actionRed,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      movie.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
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
}

class AnimeTrendingHeroCarousel extends StatefulWidget {
  final List<Movie> movies;

  const AnimeTrendingHeroCarousel({super.key, required this.movies});

  @override
  State<AnimeTrendingHeroCarousel> createState() => _AnimeTrendingHeroCarouselState();
}

class _AnimeTrendingHeroCarouselState extends State<AnimeTrendingHeroCarousel> {
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
        if (_pageController.position.isScrollingNotifier.value) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AnimeDetailScreen(movie: movie)),
        );
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: movie.backdropPath,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: AnimeColors.surface),
              errorWidget: (context, url, error) => Container(color: AnimeColors.surface),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.3, 1.0],
                  colors: [Colors.transparent, AnimeColors.background],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$rank',
                      style: GoogleFonts.stixTwoText(
                        color: AnimeColors.background,
                        fontSize: 80,
                        fontWeight: FontWeight.w900,
                        height: 0.9,
                        shadows: [
                          const Shadow(color: AnimeColors.accent, offset: Offset(2, 2)),
                          const Shadow(color: AnimeColors.accent, offset: Offset(-2, -2)),
                          const Shadow(color: AnimeColors.accent, offset: Offset(2, -2)),
                          const Shadow(color: AnimeColors.accent, offset: Offset(-2, 2)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AnimeColors.actionRed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'TRENDING',
                              style: GoogleFonts.dmSans(color: AnimeColors.background, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            movie.title,
                            style: GoogleFonts.stixTwoText(
                              color: AnimeColors.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(movie.releaseDate.split('-').first, style: GoogleFonts.dmSans(color: AnimeColors.textSecondary, fontSize: 12)),
                              const SizedBox(width: 12),
                              const Icon(Icons.star, color: AnimeColors.actionRed, size: 12),
                              const SizedBox(width: 4),
                              Text(movie.rating.toStringAsFixed(1), style: GoogleFonts.dmSans(color: AnimeColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
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
