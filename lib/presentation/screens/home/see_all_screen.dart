import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/data/models/movie_model.dart';
import 'package:watch_track/presentation/widgets/movie_card.dart';
import 'package:watch_track/presentation/screens/detail/detail_screen.dart';

class SeeAllScreen extends StatelessWidget {
  final String title;
  final List<Movie> movies;
  final String tagPrefix;

  const SeeAllScreen({
    super.key,
    required this.title,
    required this.movies,
    required this.tagPrefix,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title.toUpperCase(),
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: GridView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: movies.length,
        itemBuilder: (context, index) {
          final movie = movies[index];
          return MovieCard(
            posterUrl: movie.posterPath,
            title: movie.title,
            rating: movie.rating,
            width: double.infinity,
            margin: EdgeInsets.zero,
            heroTag: '${tagPrefix}_seeall_${movie.id}',
            onTap: () {

              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DetailScreen(movie: movie)),
              );
            },
          );
        },
      ),
    );
  }
}
