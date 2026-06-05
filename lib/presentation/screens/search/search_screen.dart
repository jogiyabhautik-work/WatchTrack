import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:watch_track/back-end/api_service.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/data/models/movie_model.dart';
import 'package:watch_track/presentation/screens/genre/genre_screen.dart';
import 'package:watch_track/presentation/screens/actor/actor_detail_screen.dart';
import 'package:watch_track/presentation/screens/detail/detail_screen.dart';
import 'package:watch_track/presentation/widgets/movie_card.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  final String? initialFilter;
  const SearchScreen({super.key, this.initialQuery, this.initialFilter});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _apiService = ApiService();
  List<Movie> _results = [];
  bool _isLoading = false;
  bool _isTyping = false;
  String? _error;
  Timer? _debounce;
  String _selectedFilter = 'All';
  final TextEditingController _controller = TextEditingController();
  String _selectedSort = 'Popularity';
  double _minRatingFilter = 0.0;
  int? _selectedYear;
  String _selectedLanguage = 'all';
  List<Movie> _cachedTrendingMovies = [];
  List<Movie> _cachedTrendingSeries = [];

  final List<String> _displayGenres = [
    'Action', 'Horror', 'Comedy', 'Romance', 
    'Sci-Fi', 'Drama', 'Animation', 'Thriller'
  ];

  final Map<String, List<Color>> _genreGradients = {
    'Action': [const Color(0xFF1A0000), const Color(0xFF7B0D0D)],
    'Horror': [const Color(0xFF0A0010), const Color(0xFF2D0050)],
    'Comedy': [const Color(0xFF1A1500), const Color(0xFF5C4D00)],
    'Romance': [const Color(0xFF1A000A), const Color(0xFF660033)],
    'Sci-Fi': [const Color(0xFF000D1A), const Color(0xFF003366)],
    'Drama': [const Color(0xFF0A0A0A), const Color(0xFF1F1F1F)],
    'Animation': [const Color(0xFF001A0D), const Color(0xFF006633)],
    'Thriller': [const Color(0xFF0D0000), const Color(0xFF4D0000)],
  };

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _selectedFilter = widget.initialFilter!;
    }
    
    _focusNode.addListener(() {
      setState(() {}); // Rebuild to show/hide suggestions overlay
    });

    if (widget.initialQuery != null) {
      _controller.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
        _isTyping = false;
        _error = null;
      });
      return;
    }

    setState(() => _isTyping = true);
    
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _isTyping = false;
      _error = null;
    });

    try {
      final results = await _apiService.search(
        query, 
        type: _selectedFilter,
        year: _selectedYear,
        language: _selectedLanguage,
      );
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load results. Please try again.';
          _isLoading = false;
        });
      }
    }
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
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter Results',
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'SORT BY',
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
                      children: ['Popularity', 'Date', 'Rating'].map((sort) {
                        final isSelected = _selectedSort == sort;
                        return ChoiceChip(
                          label: Text(sort),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => _selectedSort = sort);
                              setState(() => _selectedSort = sort);
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
                    Text(
                      'MINIMUM RATING',
                      style: GoogleFonts.dmSans(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, color: AppColors.ratingGold, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Slider(
                            value: _minRatingFilter,
                            min: 0,
                            max: 10,
                            divisions: 10,
                            activeColor: AppColors.primary,
                            inactiveColor: AppColors.background,
                            label: _minRatingFilter.toStringAsFixed(1),
                            onChanged: (value) {
                              setModalState(() => _minRatingFilter = value);
                              setState(() => _minRatingFilter = value);
                            },
                          ),
                        ),
                        Text(
                          _minRatingFilter.toStringAsFixed(1),
                          style: GoogleFonts.dmSans(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'RELEASE YEAR',
                      style: GoogleFonts.dmSans(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      initialValue: _selectedYear,
                      dropdownColor: AppColors.surface,
                      style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Any Year')),
                        ...List.generate(30, (i) => 2024 - i).map((year) => DropdownMenuItem(value: year, child: Text(year.toString()))),
                      ],
                      onChanged: (val) {
                        setModalState(() => _selectedYear = val);
                        setState(() => _selectedYear = val);
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'LANGUAGE',
                      style: GoogleFonts.dmSans(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedLanguage,
                      dropdownColor: AppColors.surface,
                      style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Languages')),
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                        DropdownMenuItem(value: 'es', child: Text('Spanish')),
                        DropdownMenuItem(value: 'fr', child: Text('French')),
                        DropdownMenuItem(value: 'ja', child: Text('Japanese')),
                        DropdownMenuItem(value: 'ko', child: Text('Korean')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => _selectedLanguage = val);
                          setState(() => _selectedLanguage = val);
                        }
                      },
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (_controller.text.isNotEmpty) {
                            _performSearch(_controller.text);
                          }
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
              ),
            );
          },
        );
      },
    );
  }

  List<Movie> _getFilteredResults(List<Movie> movies) {
    List<Movie> filtered = movies;
    
    // Server-side filtering is now largely handled by ApiService.search(..., type: _selectedFilter)
    // but we can keep local filtering for safety or additional criteria like rating.

    // Apply Min Rating Filter
    filtered = filtered.where((m) => m.rating >= _minRatingFilter).toList();

    // Apply Sort
    if (_selectedSort == 'Date') {
      filtered.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
    } else if (_selectedSort == 'Rating') {
      filtered.sort((a, b) => b.rating.compareTo(a.rating));
    }

    // De-duplicate results by TMDB ID to prevent Hero tag collisions
    final seenIds = <String>{};
    filtered = filtered.where((m) => seenIds.add(m.id)).toList();

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.6, -0.8),
                  radius: 1.2,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                    'Discover',
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Search Bar
                  TextField(
                    focusNode: _focusNode,
                    controller: _controller,
                    onChanged: _onSearch,
                    style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Title, actor, director…',
                      hintStyle: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 14),
                      fillColor: AppColors.surface2,
                      filled: true,
                      prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 18),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isTyping)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.tune_rounded, color: AppColors.textMuted, size: 18),
                            onPressed: () => _showFilterBottomSheet(),
                          ),
                        ],
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter Chips
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildChip('All'),
                        _buildChip('Movies'),
                        _buildChip('TV Shows'),
                        _buildChip('Anime'),
                        _buildChip('Cartoon'),
                        _buildChip('People'),
                        _buildChip('Genres'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _selectedFilter == 'Genres' 
                        ? _buildGenresGrid()
                        : _buildResultsView(),
                  ),
                ],
              ),
            ),
            if (_controller.text.isNotEmpty && _focusNode.hasFocus)
                  Positioned(
                    top: 100,
                    left: 20,
                    right: 20,
                    bottom: 0,
                    child: _buildSuggestionsOverlay(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsOverlay() {
    if (_isTyping || _isLoading) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_results.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final movie = _results[index];
          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: movie.posterPath,
                width: 40,
                height: 60,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(width: 40, height: 60, color: AppColors.surface2),
              ),
            ),
            title: Text(movie.title, style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14)),
            subtitle: Text(
              movie.releaseDate.split('-').first,
              style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 12),
            ),
            onTap: () {
              _focusNode.unfocus();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DetailScreen(movie: movie, heroTag: 'sug_${movie.id}')),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleRefresh() async {
    if (_controller.text.isEmpty) {
      setState(() => _isLoading = true);
      try {
        if (_selectedFilter == 'TV Shows') {
          _cachedTrendingSeries = await _apiService.getTrendingSeries(forceRefresh: true);
        } else {
          _cachedTrendingMovies = await _apiService.getTrendingMovies(forceRefresh: true);
        }
      } catch (e) {
        debugPrint('Refresh Error: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      await _performSearch(_controller.text);
    }
  }

  Widget _buildResultsView() {
    if (_error != null) {
      return _buildErrorState();
    }

    if (_isLoading) {
      return _buildShimmerGrid();
    }    return RefreshIndicator(
      onRefresh: _handleRefresh,
      backgroundColor: AppColors.surface,
      color: AppColors.primary,
      child: FutureBuilder<List<Movie>>(
        future: _controller.text.isEmpty 
            ? (_selectedFilter == 'TV Shows' 
                ? ((_cachedTrendingSeries.isNotEmpty) ? Future.value(_cachedTrendingSeries) : _apiService.getTrendingSeries().then((v) { _cachedTrendingSeries = v; return v; }))
                : ((_cachedTrendingMovies.isNotEmpty) ? Future.value(_cachedTrendingMovies) : _apiService.getTrendingMovies().then((v) { _cachedTrendingMovies = v; return v; })))
            : Future.value(_results),
        builder: (context, snapshot) {
          final List<Movie> data = snapshot.data ?? [];
          final displayList = _getFilteredResults(data);
          
          if (displayList.isEmpty && _controller.text.isNotEmpty) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: _buildEmptyState(),
              ),
            );
          }
  
          return GridView.builder(
            key: PageStorageKey('search_results_$_selectedFilter'),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: displayList.length,
            itemBuilder: (context, index) {
              final movie = displayList[index];
              if (_selectedFilter == 'People') {
                return _buildPersonCard(movie);
              }
              return _buildResultCard(movie);
            },
          );
        },
      ),
    );
  }

  Widget _buildResultCard(Movie movie) {
    return MovieCard(
      posterUrl: movie.posterPath,
      title: movie.title,
      rating: movie.rating,
      heroTag: 'search_${movie.id}',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DetailScreen(movie: movie, heroTag: 'search_${movie.id}')),
        );
      },
    );
  }

  Widget _buildGenresGrid() {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _displayGenres.length,
      itemBuilder: (context, index) {
        final genre = _displayGenres[index];
        final gradient = _genreGradients[genre] ?? [AppColors.surface, AppColors.surface2];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => GenreScreen(genreName: genre)),
            );
          },
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              genre,
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPersonCard(Movie person) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ActorDetailScreen(actorId: person.id)),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: person.posterPath,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: AppColors.surface2),
                errorWidget: (context, url, error) => Container(color: AppColors.surface2),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Text(
                person.title,
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (_selectedFilter != label) {
          setState(() {
            _selectedFilter = label;
            // If there's an existing query, re-run search with new filter
            if (_controller.text.isNotEmpty) {
              _performSearch(_controller.text);
            }
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: AppColors.borderDefault),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surface2,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, color: AppColors.textMuted, size: 64),
          const SizedBox(height: 16),
          Text(
            'No results for "${_controller.text}"',
            style: GoogleFonts.dmSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching for something else',
            style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.primary, size: 48),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: GoogleFonts.dmSans(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _performSearch(_controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
