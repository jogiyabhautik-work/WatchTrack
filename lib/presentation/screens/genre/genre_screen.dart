import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:watch_track/back-end/api_service.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/data/models/movie_model.dart';
import 'package:watch_track/presentation/widgets/movie_card.dart';
import 'package:watch_track/presentation/screens/detail/detail_screen.dart';

class GenreScreen extends StatefulWidget {
  final String genreName;

  const GenreScreen({super.key, required this.genreName});

  @override
  State<GenreScreen> createState() => _GenreScreenState();
}

class _GenreScreenState extends State<GenreScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  final List<Movie> _movies = [];
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;

  // Filter State
  String _selectedLanguage = 'all';
  String _selectedSort = 'popularity.desc';
  String _selectedAvailability = 'all';

  final List<Map<String, String>> _languages = [
    {'name': 'All Languages', 'id': 'all'},
    {'name': 'English', 'id': 'en'},
    {'name': 'Spanish', 'id': 'es'},
    {'name': 'French', 'id': 'fr'},
    {'name': 'Japanese', 'id': 'ja'},
    {'name': 'Korean', 'id': 'ko'},
    {'name': 'Hindi', 'id': 'hi'},
  ];

  final List<Map<String, String>> _sortOptions = [
    {'name': 'Most Popular', 'id': 'popularity.desc'},
    {'name': 'Newest First', 'id': 'release_date.desc'},
    {'name': 'Highest Rated', 'id': 'vote_average.desc'},
  ];

  final List<Map<String, String>> _availabilities = [
    {'name': 'All', 'id': 'all'},
    {'name': 'Stream (Ads/Free)', 'id': 'free|ads'},
    {'name': 'Streaming (Flatrate)', 'id': 'flatrate'},
    {'name': 'Rent/Buy', 'id': 'rent|buy'},
  ];

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _movies.clear();
      _currentPage = 1;
      _hasMore = true;
    });
    await _loadMore(forceRefresh: true);
  }

  Future<void> _loadMore({bool forceRefresh = false}) async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final newMovies = await _apiService.getMoviesByGenre(
        widget.genreName, 
        page: _currentPage,
        language: _selectedLanguage,
        sortBy: _selectedSort,
        monetization: _selectedAvailability,
        forceRefresh: forceRefresh,
      );

      setState(() {
        _isLoading = false;
        if (newMovies.isEmpty) {
          _hasMore = false;
        } else {
          _movies.addAll(newMovies);
          _currentPage++;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _movies.clear();
      _currentPage = 1;
      _hasMore = true;
    });
    _loadMore();
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter ${_widgetGenreName()}',
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Sort Section
                  _buildFilterLabel('SORT BY'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _sortOptions.map((opt) {
                      final isSelected = _selectedSort == opt['id'];
                      return ChoiceChip(
                        label: Text(opt['name']!),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() => _selectedSort = opt['id']!);
                            setState(() => _selectedSort = opt['id']!);
                          }
                        },
                        labelStyle: GoogleFonts.dmSans(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        backgroundColor: AppColors.background,
                        selectedColor: AppColors.primary,
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Language Section
                  _buildFilterLabel('ORIGINAL LANGUAGE'),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _languages.map((lang) {
                        final isSelected = _selectedLanguage == lang['id'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(lang['name']!),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setModalState(() => _selectedLanguage = lang['id']!);
                                setState(() => _selectedLanguage = lang['id']!);
                              }
                            },
                            labelStyle: GoogleFonts.dmSans(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            backgroundColor: AppColors.background,
                            selectedColor: AppColors.primary,
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  // Availability Section
                  _buildFilterLabel('AVAILABILITY (US REGION)'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _availabilities.map((opt) {
                      final isSelected = _selectedAvailability == opt['id'];
                      return ChoiceChip(
                        label: Text(opt['name']!),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() => _selectedAvailability = opt['id']!);
                            setState(() => _selectedAvailability = opt['id']!);
                          }
                        },
                        labelStyle: GoogleFonts.dmSans(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        backgroundColor: AppColors.background,
                        selectedColor: AppColors.primary,
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _applyFilters();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        'APPLY FILTERS',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _widgetGenreName() => widget.genreName;

  Widget _buildFilterLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        color: AppColors.textMuted,
        fontSize: 10,
        letterSpacing: 2,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.genreName.toUpperCase(),
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
            onPressed: _showFilterBottomSheet,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        backgroundColor: AppColors.surface,
        color: AppColors.primary,
        displacement: 100,
        child: _movies.isEmpty && _isLoading 
            ? _buildShimmerGrid() 
            : _buildMoviesGrid(),
      ),
    );
  }

  Widget _buildMoviesGrid() {
    return GridView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 120, 16, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _movies.length + (_hasMore ? 2 : 0),
      itemBuilder: (context, index) {
        if (index < _movies.length) {
          final movie = _movies[index];
          return MovieCard(
            posterUrl: movie.posterPath,
            title: movie.title,
            rating: movie.rating,
            width: double.infinity,
            margin: EdgeInsets.zero,
            heroTag: 'genre_gallery_${widget.genreName}_${movie.id}',
            onTap: () {

              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DetailScreen(movie: movie)),
              );
            },
          );
        } else {
          return _buildSingleShimmerCard();
        }
      },
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 120, 16, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 8,
      itemBuilder: (context, index) => _buildSingleShimmerCard(),
    );
  }

  Widget _buildSingleShimmerCard() {
    return Shimmer.fromColors(
      baseColor: AppColors.surface2,
      highlightColor: AppColors.surface,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
