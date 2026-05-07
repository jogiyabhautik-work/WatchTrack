import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/data/models/movie_model.dart';
import 'package:watch_track/back-end/api_service.dart';
import 'package:watch_track/presentation/screens/anime/anime_home_screen.dart';
import 'package:watch_track/presentation/screens/anime/anime_detail_screen.dart';

class AnimeActorDetailScreen extends StatefulWidget {
  final String actorId;
  const AnimeActorDetailScreen({super.key, required this.actorId});

  @override
  State<AnimeActorDetailScreen> createState() => _AnimeActorDetailScreenState();
}

class _AnimeActorDetailScreenState extends State<AnimeActorDetailScreen> {
  final ApiService _apiService = ApiService();
  Actor? _actor;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActor();
  }

  Future<void> _loadActor({bool forceRefresh = false}) async {
    final actor = await _apiService.getActorDetails(widget.actorId, forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _actor = actor;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRefresh() async {
    await _loadActor(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AnimeColors.background,
        body: Center(child: CircularProgressIndicator(color: AnimeColors.accent)),
      );
    }

    if (_actor == null) {
      return const Scaffold(
        backgroundColor: AnimeColors.background,
        body: Center(child: Text('Actor not found')),
      );
    }

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
            _buildSliverHeader(_actor!),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    Text(
                      _actor!.name.toUpperCase(),
                      style: GoogleFonts.stixTwoText(
                        color: AnimeColors.textPrimary,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'VOICE ACTOR / 声優',
                      style: GoogleFonts.dmSans(
                        color: AnimeColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildBiography(_actor!),
                    const SizedBox(height: 40),
                    _buildMangaPanel('NOTABLE WORKS', _actor!.movieCredits),
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

  Widget _buildSliverHeader(Actor actor) {
    return SliverAppBar(
      expandedHeight: 450,
      backgroundColor: AnimeColors.background,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: AnimeColors.accent),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: CachedNetworkImage(
          imageUrl: actor.profilePath,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) => Container(
            color: AnimeColors.surface,
            child: const Icon(Icons.person, color: AnimeColors.accent, size: 50),
          ),
        ),
      ),
    );
  }

  Widget _buildBiography(Actor actor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BIOGRAPHY',
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
            border: Border.all(color: AnimeColors.border, width: 2),
            color: AnimeColors.surface,
          ),
          child: Text(
            actor.biography.isNotEmpty ? actor.biography : 'No biography available.',
            style: GoogleFonts.dmSans(
              color: AnimeColors.textPrimary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMangaPanel(String title, List<Movie> credits) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.dmSans(
            color: AnimeColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: credits.length,
            itemBuilder: (context, index) {
              final movie = credits[index];
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => AnimeDetailScreen(movie: movie))),
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
                          ),
                          child: CachedNetworkImage(
                            imageUrl: movie.posterPath,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorWidget: (context, url, error) => Container(
                              color: AnimeColors.surface,
                              child: const Icon(Icons.movie_outlined, color: AnimeColors.accent),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        movie.title.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.stixTwoText(
                          color: AnimeColors.textPrimary,
                          fontSize: 11,
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
