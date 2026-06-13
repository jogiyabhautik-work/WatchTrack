import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:watch_track/back-end/api_service.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/data/models/movie_model.dart';
import 'package:watch_track/presentation/widgets/movie_card.dart';
import 'package:watch_track/presentation/screens/detail/detail_screen.dart';

class ActorDetailScreen extends StatefulWidget {
  final String actorId;

  const ActorDetailScreen({super.key, required this.actorId});

  @override
  State<ActorDetailScreen> createState() => _ActorDetailScreenState();
}

class _ActorDetailScreenState extends State<ActorDetailScreen> {
  final ApiService _apiService = ApiService();
  late Future<Actor?> _actorDetails;
  bool _isBioExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData({bool forceRefresh = false}) {
    setState(() {
      _actorDetails = _apiService.getActorDetails(widget.actorId, forceRefresh: forceRefresh);
    });
  }

  Future<void> _handleRefresh() async {
    _loadData(forceRefresh: true);
    await _actorDetails;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<Actor?>(
        future: _actorDetails,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Error loading actor details'));
          }

          final actor = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            backgroundColor: AppColors.surface,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SECTION: Header
                  _buildHeader(actor),
  
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // BIOGRAPHY
                        _buildBiography(actor),
  
                        const SizedBox(height: 32),
  
                        // KNOWN FOR
                        _buildKnownFor(actor),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(Actor actor) {
    final screenHeight = MediaQuery.of(context).size.height;
    return SizedBox(
      height: screenHeight * 0.48, // Responsive height approx 380px on standard devices
      width: double.infinity,
      child: Stack(
        children: [
          // Profile Image
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: actor.profilePath,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
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
                  stops: const [0.5, 1.0],
                  colors: [
                    Colors.transparent,
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
          // Back Button
          Positioned(
            top: 40,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
              ),
            ),
          ),
          // Actor Info
          Positioned(
            left: 20,
            bottom: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actor.name,
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (actor.birthday.isNotEmpty)
                  Text(
                    'Born · ${actor.birthday} · ${actor.placeOfBirth}',
                    style: GoogleFonts.dmSans(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
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
            color: AppColors.textMuted,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          actor.biography,
          maxLines: _isBioExpanded ? null : 5,
          overflow: _isBioExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _isBioExpanded = !_isBioExpanded),
          child: Text(
            _isBioExpanded ? 'Read less' : 'Read more',
            style: GoogleFonts.dmSans(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKnownFor(Actor actor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'KNOWN FOR',
          style: GoogleFonts.dmSans(
            color: AppColors.textMuted,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: actor.movieCredits.length,
            itemBuilder: (context, index) {
              final movie = actor.movieCredits[index];
              return MovieCard(
                posterUrl: movie.posterPath,
                title: movie.title,
                rating: movie.rating,
                heroTag: 'actor_credit_${actor.id}_${movie.id}',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => DetailScreen(movie: movie)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
