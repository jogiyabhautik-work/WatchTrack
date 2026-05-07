import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/data/models/movie_model.dart';
import 'package:watch_track/back-end/api_service.dart';
import 'package:watch_track/core/providers/recommendation_provider.dart';
import 'package:watch_track/core/providers/user_data_provider.dart';
import 'package:watch_track/core/providers/tracking_provider.dart';
import 'package:watch_track/presentation/screens/anime/anime_detail_screen.dart';
import 'package:watch_track/presentation/screens/search/search_screen.dart';

class AnimeColors {
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF0F0F0);
  static const Color accent = Color(0xFF000000);
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF666666);
  static const Color border = Color(0xFF000000);
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

  final TextEditingController _searchController = TextEditingController();
  List<Movie> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchingLoading = false;
  Timer? _debounce;

  String? _selectedStudio;
  String? _selectedYear;
  
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

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _isSearchingLoading = true;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await _apiService.search(query, type: 'Anime');
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearchingLoading = false;
        });
      }
    });
  }

  void _refreshData({bool forceRefresh = false}) {
    _trendingAnime = _apiService.getTrendingAnime(forceRefresh: forceRefresh);
    _topRatedAnime = _apiService.getAnimeByCategory('Top Rated', forceRefresh: forceRefresh);
    _seasonalAnime = _apiService.getAnimeByCategory('Seasonal', forceRefresh: forceRefresh);
    
    // Refresh recommendations if provider is available
    final recProvider = context.read<RecommendationProvider>();
    final userData = context.read<UserDataProvider>();
    final tracking = context.read<TrackingProvider>();
    recProvider.refreshRecommendations(userData, tracking, force: forceRefresh);
  }

  void _applyFilters({bool forceRefresh = false}) {
    setState(() {
      if (_selectedStudio != null) {
        _trendingAnime = _apiService.getAnimeByStudio(_studios[_selectedStudio]!, forceRefresh: forceRefresh);
      } else {
        _trendingAnime = _apiService.getTrendingAnime(forceRefresh: forceRefresh);
      }
    });
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _refreshData(forceRefresh: true);
      if (_selectedStudio != null) _applyFilters(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AnimeColors.background,
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        backgroundColor: AnimeColors.background,
        color: AnimeColors.accent,
        child: Consumer<RecommendationProvider>(
          builder: (context, recProvider, _) {
            // Filter global recommendations for anime
            final animeContinue = recProvider.continueWatching.where((m) => !m.isMovie).toList();
            final animeTopPicks = recProvider.topPicks.where((m) => !m.isMovie || m.genres.contains('Animation')).toList();
            final animeBecauseWatched = recProvider.becauseYouWatched.where((m) => !m.isMovie || m.genres.contains('Animation')).toList();
            final animeHiddenGems = recProvider.hiddenGems.where((m) => !m.isMovie || m.genres.contains('Animation')).toList();

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSearchBar(),
                      const SizedBox(height: 16),
                      
                      if (_isSearching)
                        _buildSearchResultsView()
                      else ...[
                        _buildHeroSection(),
                        const SizedBox(height: 32),
                        _buildCategorySection(),
                        const SizedBox(height: 32),
                        _buildQuickDiscoverySection(),
                        const SizedBox(height: 32),
                        _buildFilterBar(),
                        const SizedBox(height: 32),
                        
                        if (animeContinue.isNotEmpty)
                          _buildSection('CONTINUE WATCHING', Future.value(animeContinue)),
                          
                        _buildSection('TRENDING NOW', _trendingAnime),
                        
                        if (animeTopPicks.isNotEmpty)
                          _buildSection('TOP PICKS FOR YOU', Future.value(animeTopPicks)),
                          
                        _buildSection('SEASONAL HITS', _seasonalAnime),
                        
                        if (animeBecauseWatched.isNotEmpty)
                          _buildSection('BECAUSE YOU WATCHED', Future.value(animeBecauseWatched)),
                          
                        _buildSection('TOP RATED', _topRatedAnime),
                        
                        if (animeHiddenGems.isNotEmpty)
                          _buildSection('HIDDEN GEMS', Future.value(animeHiddenGems)),
                      ],
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: AnimeColors.background,
      elevation: 0,
      pinned: true,
      centerTitle: false,
      automaticallyImplyLeading: false,
      title: Row(
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
      actions: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchScreen())),
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: AnimeColors.border, width: 2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search, color: AnimeColors.accent, size: 20),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: AnimeColors.border,
          height: 2,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        height: 55,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AnimeColors.background,
          border: Border.all(color: AnimeColors.border, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(4, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: AnimeColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: GoogleFonts.dmSans(
                  color: AnimeColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
                decoration: InputDecoration(
                  hintText: 'SEARCH ANIME...',
                  hintStyle: GoogleFonts.dmSans(
                    color: AnimeColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (_isSearching)
              IconButton(
                icon: const Icon(Icons.close, color: AnimeColors.accent, size: 20),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AnimeColors.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'GO',
                  style: GoogleFonts.dmSans(
                    color: AnimeColors.background,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsView() {
    if (_isSearchingLoading) {
      return const SizedBox(
        height: 400,
        child: Center(child: CircularProgressIndicator(color: AnimeColors.accent)),
      );
    }

    if (_searchResults.isEmpty) {
      return SizedBox(
        height: 400,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off_rounded, color: AnimeColors.accent, size: 64),
              const SizedBox(height: 16),
              Text(
                'NO RESULTS FOUND',
                style: GoogleFonts.dmSans(color: AnimeColors.textPrimary, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Text(
            'SEARCH RESULTS',
            style: GoogleFonts.dmSans(color: AnimeColors.textSecondary, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w900),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            crossAxisSpacing: 16,
            mainAxisSpacing: 24,
          ),
          itemCount: _searchResults.length,
          itemBuilder: (context, index) {
            return _MangaCard(movie: _searchResults[index]);
          },
        ),
      ],
    );
  }

  Widget _buildHeroSection() {
    return FutureBuilder<List<Movie>>(
      future: _trendingAnime,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox(height: 300);
        }
        final hero = snapshot.data!.first;
        return GestureDetector(
          onTap: () {
            HapticFeedback.heavyImpact();
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => AnimeDetailScreen(movie: hero),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOutQuart;
                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 700),
              ),
            );
          },
          child: Container(
            height: 450,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AnimeColors.border, width: 4)),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: hero.backdropPath,
                    fit: BoxFit.cover,
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
                          AnimeColors.background.withOpacity(0.8),
                          AnimeColors.background,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 40,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AnimeColors.accent,
                          border: Border.all(color: AnimeColors.background, width: 2),
                        ),
                        child: Text(
                          'FEATURED',
                          style: GoogleFonts.dmSans(
                            color: AnimeColors.background,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        hero.title.toUpperCase(),
                        style: GoogleFonts.stixTwoText(
                          color: AnimeColors.textPrimary,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          height: 0.9,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildSection(String title, Future<List<Movie>> future) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 24,
                color: AnimeColors.accent,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.dmSans(
                  color: AnimeColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 280,
          child: FutureBuilder<List<Movie>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildSkeletonList();
              }
              final data = snapshot.data ?? [];
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: data.length,
                itemBuilder: (context, index) {
                  return _MangaCard(movie: data[index]);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 5,
      itemBuilder: (context, index) => Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AnimeColors.surface,
          border: Border.all(color: AnimeColors.border, width: 2),
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    final List<String> animeGenres = [
      'Action', 'Adventure', 'Comedy', 'Drama', 'Fantasy', 
      'Horror', 'Mystery', 'Romance', 'Sci-Fi', 'Thriller', 'Slice of Life'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            'BROWSE BY GENRE',
            style: GoogleFonts.dmSans(
              color: AnimeColors.textSecondary,
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 45,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: animeGenres.length,
            itemBuilder: (context, index) {
              final genre = animeGenres[index];
              return _buildFilterChip(genre, false, () {
                // Navigate to filtered search or genre screen
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickDiscoverySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            'QUICK DISCOVERY',
            style: GoogleFonts.dmSans(
              color: AnimeColors.textSecondary,
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildDiscoveryCard(
                'Mood Picker',
                'How you feeling?',
                Icons.emoji_emotions_outlined,
                Colors.black,
                () => _showMoodPicker(),
              ),
              _buildDiscoveryCard(
                'Surprise Me',
                'One tap roll',
                Icons.casino_outlined,
                Colors.black,
                () => _pickRandomAnime(),
              ),
              _buildDiscoveryCard(
                'Binge Plan',
                'Weekend guide',
                Icons.calendar_today_outlined,
                Colors.black,
                () {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoveryCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AnimeColors.background,
          border: Border.all(color: AnimeColors.border, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(4, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: double.infinity,
              color: AnimeColors.accent,
              child: Icon(icon, color: AnimeColors.background, size: 24),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: GoogleFonts.dmSans(color: AnimeColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.dmSans(color: AnimeColors.textSecondary, fontSize: 9),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
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
      backgroundColor: AnimeColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) {
        final moods = [
          {'name': 'Epic', 'genre': 'Action', 'icon': '⚔️'},
          {'name': 'Fun', 'genre': 'Comedy', 'icon': '✨'},
          {'name': 'Dark', 'genre': 'Horror', 'icon': '💀'},
          {'name': 'Sad', 'genre': 'Drama', 'icon': '💧'},
          {'name': 'Magic', 'genre': 'Fantasy', 'icon': '🔮'},
          {'name': 'Hype', 'genre': 'Sports', 'icon': '🔥'},
        ];
        return Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AnimeColors.border, width: 5)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'WHAT IS YOUR MOOD?',
                style: GoogleFonts.stixTwoText(color: AnimeColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w900),
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
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AnimeColors.background,
                        border: Border.all(color: AnimeColors.border, width: 3),
                        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(mood['icon']!, style: const TextStyle(fontSize: 24)),
                          const SizedBox(height: 8),
                          Text(
                            mood['name']!.toUpperCase(),
                            style: GoogleFonts.dmSans(color: AnimeColors.textPrimary, fontSize: 10, fontWeight: FontWeight.w900),
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

  void _pickRandomAnime() async {
    final anime = await _trendingAnime;
    if (anime.isNotEmpty && mounted) {
      final random = anime[DateTime.now().millisecond % anime.length];
      Navigator.push(context, MaterialPageRoute(builder: (context) => AnimeDetailScreen(movie: random)));
    }
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FILTER BY STUDIO',
            style: GoogleFonts.dmSans(
              color: AnimeColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFilterChip('All', _selectedStudio == null, () {
                  setState(() => _selectedStudio = null);
                  _applyFilters();
                }),
                ..._studios.keys.map((studio) => _buildFilterChip(
                  studio, 
                  _selectedStudio == studio, 
                  () {
                    setState(() => _selectedStudio = studio);
                    _applyFilters();
                  }
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AnimeColors.accent : AnimeColors.background,
          border: Border.all(color: AnimeColors.border, width: 2),
        ),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.dmSans(
            color: isSelected ? AnimeColors.background : AnimeColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MangaCard extends StatelessWidget {
  final Movie movie;
  const _MangaCard({required this.movie});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => AnimeDetailScreen(movie: movie),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOutQuart;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      },
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AnimeColors.border, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      offset: const Offset(8, 8),
                    ),
                  ],
                ),
                child: CachedNetworkImage(
                  imageUrl: movie.posterPath,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              movie.title.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.stixTwoText(
                color: AnimeColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              movie.releaseDate.split('-').first,
              style: GoogleFonts.dmSans(
                color: AnimeColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
