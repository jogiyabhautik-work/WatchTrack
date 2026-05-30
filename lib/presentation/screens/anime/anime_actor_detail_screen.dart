import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/data/models/movie_model.dart';
import 'package:watch_track/back-end/api_service.dart';
import 'package:watch_track/presentation/screens/anime/anime_home_screen.dart';
import 'package:watch_track/presentation/screens/anime/anime_detail_screen.dart';
import 'package:watch_track/presentation/widgets/anime/manga_panel_painter.dart';

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
      body: Stack(
        children: [
          _buildScreentoneBackground(),
          RefreshIndicator(
            onRefresh: _handleRefresh,
            backgroundColor: AnimeColors.background,
            color: AnimeColors.actionRed,
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
                        _buildProfileInfo(_actor!),
                        const SizedBox(height: 32),
                        _buildBiography(_actor!),
                        const SizedBox(height: 48),
                        _buildMangaPanel('NOTABLE WORKS / 代表作', _actor!.movieCredits),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildBottomIndicator(),
        ],
      ),
    );
  }

  Widget _buildScreentoneBackground() {
    return Positioned.fill(
      child: CustomPaint(
        painter: MangaPanelPainter(
          showScreentone: true,
          screentoneColor: AnimeColors.screentone.withOpacity(0.03),
        ),
      ),
    );
  }

  Widget _buildBottomIndicator() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 2,
        color: AnimeColors.border,
      ),
    );
  }

  Widget _buildProfileInfo(Actor actor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              color: AnimeColors.actionRed,
              child: Text(
                'ACTOR PROFILE',
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '声優',
              style: GoogleFonts.dmSans(
                color: Colors.black45,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          actor.name.toUpperCase(),
          style: GoogleFonts.stixTwoText(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            height: 0.9,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Container(height: 6, width: 100, color: Colors.black),
      ],
    );
  }

  Widget _buildSliverHeader(Actor actor) {
    return SliverAppBar(
      expandedHeight: 450,
      backgroundColor: AnimeColors.background,
      elevation: 0,
      pinned: true,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.white,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: actor.profilePath,
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _SpeedLinesPainter(),
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
                      Colors.black.withOpacity(0.3),
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

  Widget _buildBiography(Actor actor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'THE LEGEND',
          style: GoogleFonts.dmSans(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 16),
        MangaPanel(
          child: Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Text(
              actor.biography.isNotEmpty ? actor.biography : 'THE STORY IS YET TO BE WRITTEN...',
              style: GoogleFonts.dmSans(
                color: Colors.black,
                fontSize: 15,
                height: 1.6,
              ),
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
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: credits.length,
            itemBuilder: (context, index) {
              final movie = credits[index];
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => AnimeDetailScreen(movie: movie))),
                child: Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: MangaPanel(
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
                          fontSize: 13,
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
}

class _SpeedLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1.0;

    final random = math.Random(42);
    for (int i = 0; i < 30; i++) {
      double angle = random.nextDouble() * 2 * math.pi;
      double length = random.nextDouble() * 200 + 100;
      double startX = size.width / 2 + math.cos(angle) * (size.width / 4);
      double startY = size.height / 2 + math.sin(angle) * (size.height / 3);
      double endX = startX + math.cos(angle) * length;
      double endY = startY + math.sin(angle) * length;
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
