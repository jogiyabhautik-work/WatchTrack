import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/presentation/screens/main_screen.dart';
import 'package:watch_track/back-end/api_service.dart';
import 'package:watch_track/data/models/movie_model.dart';
import 'package:provider/provider.dart';
import 'package:watch_track/core/providers/user_data_provider.dart';
import 'package:watch_track/core/providers/tracking_provider.dart';
import 'package:watch_track/data/models/user_title_model.dart';

class OnboardingLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget content;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const OnboardingLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: onSkip,
            child: Text('Skip', style: GoogleFonts.dmSans(color: AppColors.textMuted)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.dmSans(
                color: AppColors.textMuted,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            Expanded(child: content),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('CONTINUE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GenrePickerScreen extends StatefulWidget {
  const GenrePickerScreen({super.key});

  @override
  State<GenrePickerScreen> createState() => _GenrePickerScreenState();
}

class _GenrePickerScreenState extends State<GenrePickerScreen> {
  final List<String> _genres = [
    'Action', 'Adventure', 'Animation', 'Comedy', 'Crime', 
    'Documentary', 'Drama', 'Family', 'Fantasy', 'Horror', 
    'Mystery', 'Romance', 'Sci-Fi', 'Thriller'
  ];
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return OnboardingLayout(
      title: 'Pick Genres',
      subtitle: 'Select at least 3 genres you enjoy watching.',
      onNext: () {
        if (_selected.isNotEmpty) {
          context.read<UserDataProvider>().saveOnboardingGenres(_selected);
        }
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const FavoritePickerScreen()));
      },
      onSkip: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const FavoritePickerScreen())),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: _genres.map((genre) {
          final isSelected = _selected.contains(genre);
          return FilterChip(
            label: Text(genre),
            selected: isSelected,
            onSelected: (val) {
              setState(() {
                if (val) _selected.add(genre);
                else _selected.remove(genre);
              });
            },
            selectedColor: AppColors.primary.withOpacity(0.2),
            checkmarkColor: AppColors.primary,
            labelStyle: GoogleFonts.dmSans(
              color: isSelected ? AppColors.primary : Colors.white70,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class FavoritePickerScreen extends StatefulWidget {
  const FavoritePickerScreen({super.key});

  @override
  State<FavoritePickerScreen> createState() => _FavoritePickerScreenState();
}

class _FavoritePickerScreenState extends State<FavoritePickerScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<Movie> _results = [];
  final Set<Movie> _selectedMovies = {};
  bool _isSearching = false;

  void _onSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await _apiService.search(query);
      setState(() => _results = results.where((m) => m.genres.first != 'Person').toList());
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingLayout(
      title: 'Favorites',
      subtitle: 'Search and add your all-time favorite movies or shows.',
      onNext: () async {
        if (_selectedMovies.isNotEmpty) {
          final tracking = context.read<TrackingProvider>();
          for (var movie in _selectedMovies) {
            await tracking.updateStatus(movie, TrackingStatus.watched);
            await tracking.toggleFavorite(movie);
          }
        }
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ActorPickerScreen()));
      },
      onSkip: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ActorPickerScreen())),
      content: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearch,
            decoration: InputDecoration(
              hintText: 'Search movies or shows...',
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              suffixIcon: _isSearching ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))) : null,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _results.isEmpty
                ? const Center(child: Text('Search for movies or shows to add', style: TextStyle(color: Colors.white30)))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final movie = _results[index];
                      final isSelected = _selectedMovies.any((m) => m.id == movie.id);
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CachedNetworkImage(
                            imageUrl: movie.posterPath,
                            width: 40,
                            height: 60,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: AppColors.surface),
                            errorWidget: (context, url, error) => const Icon(Icons.error_outline, size: 16),
                          ),
                        ),
                        title: Text(movie.title, style: const TextStyle(color: Colors.white)),
                        subtitle: Text(movie.releaseDate, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        trailing: Icon(
                          isSelected ? Icons.check_circle : Icons.add_circle_outline,
                          color: isSelected ? AppColors.primary : Colors.white24,
                        ),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedMovies.removeWhere((m) => m.id == movie.id);
                            } else {
                              _selectedMovies.add(movie);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ActorPickerScreen extends StatefulWidget {
  const ActorPickerScreen({super.key});

  @override
  State<ActorPickerScreen> createState() => _ActorPickerScreenState();
}

class _ActorPickerScreenState extends State<ActorPickerScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<Movie> _results = []; // Using Movie model to represent actor search results for simplicity
  final Set<String> _selected = {};
  bool _isSearching = false;

  void _onSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await _apiService.search(query);
      setState(() => _results = results.where((m) => m.genres.first == 'Person').toList());
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingLayout(
      title: 'Top Actors',
      subtitle: 'Who are your favorite actors? We\'ll prioritize their work.',
      onNext: () {
        if (_selected.isNotEmpty) {
          context.read<UserDataProvider>().saveOnboardingActors(_selected);
        }
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AboutAppScreen()));
      },
      onSkip: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AboutAppScreen())),
      content: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearch,
            decoration: InputDecoration(
              hintText: 'Search actors...',
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              suffixIcon: _isSearching ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))) : null,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _results.isEmpty
                ? const Center(child: Text('Search for actors to add', style: TextStyle(color: Colors.white30)))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final actor = _results[index];
                      final isSelected = _selected.contains(actor.id);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) _selected.remove(actor.id);
                            else _selected.add(actor.id);
                          });
                        },
                        child: Column(
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: actor.posterPath,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      placeholder: (context, url) => Container(color: AppColors.surface),
                                      errorWidget: (context, url, error) => const Icon(Icons.error_outline),
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: AppColors.primary.withOpacity(0.4),
                                      ),
                                      child: const Center(child: Icon(Icons.check, color: Colors.white)),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              actor.title,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
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
}

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return OnboardingLayout(
      title: 'About CINE Track',
      subtitle: 'Your ultimate companion for cinematic tracking.',
      onNext: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      },
      onSkip: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      },
      content: Column(
        children: [
          _buildInfoItem(Icons.auto_awesome, 'Personalized Recommendations', 'Intelligent suggestions based on your taste.'),
          _buildInfoItem(Icons.history, 'Tracking History', 'Keep track of every movie and episode you watch.'),
          _buildInfoItem(Icons.notifications_active, 'Release Alerts', 'Never miss a premiere or a new episode.'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.dmSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(desc, style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
