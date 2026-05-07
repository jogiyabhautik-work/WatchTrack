import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:watch_track/core/constants/app_colors.dart';

class MovieCard extends StatelessWidget {
  final String posterUrl;
  final String title;
  final double rating;
  final VoidCallback? onTap;
  final String heroTag;
  final double? width;
  final EdgeInsetsGeometry? margin;


  const MovieCard({
    super.key,
    required this.posterUrl,
    required this.title,
    required this.rating,
    this.onTap,
    required this.heroTag,
    this.width,
    this.margin,
  });


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width ?? 120,
        margin: margin ?? const EdgeInsets.symmetric(horizontal: 8),

        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              // Hero Image
              Positioned.fill(
                child: Hero(
                  tag: heroTag,
                  child: CachedNetworkImage(
                    imageUrl: posterUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: AppColors.surface2,
                      highlightColor: AppColors.surface,
                      child: Container(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.surface2,
                      child: const Center(
                        child: Icon(
                          Icons.movie_outlined,
                          color: AppColors.textMuted,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Gradient Overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.5, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.85),
                      ],
                    ),
                  ),
                ),
              ),

              // Content Info
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Rating Row
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: AppColors.ratingGold,
                          size: 10,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: GoogleFonts.dmSans(
                            color: AppColors.ratingGold,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Title
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
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
