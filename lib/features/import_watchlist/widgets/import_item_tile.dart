import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/features/import_watchlist/domain/import_matcher.dart';

import 'package:watch_track/data/models/movie_model.dart';
import 'package:provider/provider.dart';
import 'package:watch_track/features/import_watchlist/presentation/watchlist_import_provider.dart';

class ImportItemTile extends StatelessWidget {
  final MatchResult result;
  final VoidCallback onToggle;

  const ImportItemTile({super.key, required this.result, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: _buildLeading(),
        title: Text(
          result.matchedMovie?.title ?? result.cleanedTitle,
          style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.matchedMovie != null)
              Text(
                '${result.matchedMovie!.releaseDate.split('-').first} • ${result.matchedMovie!.isMovie ? 'Movie' : 'TV Show'}',
                style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 12),
              ),
            const SizedBox(height: 4),
            Text(
              'Original: ${result.originalTitle}',
              style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (result.status == MatchStatus.needsReview && result.alternativeMatches.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildAlternativesDropdown(context),
            ],
            if (result.status == MatchStatus.duplicate) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                child: Text('Already Tracking', style: GoogleFonts.dmSans(color: Colors.orange, fontSize: 10)),
              ),
            ],
          ],
        ),
        trailing: _buildTrailing(),
        onTap: (result.matchedMovie != null && result.status != MatchStatus.duplicate) ? onToggle : null,
      ),
    );
  }

  Widget _buildAlternativesDropdown(BuildContext context) {
    return DropdownButton<Movie>(
      isExpanded: true,
      dropdownColor: AppColors.surface,
      value: result.matchedMovie,
      icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
      underline: Container(height: 1, color: Colors.white24),
      style: GoogleFonts.dmSans(color: Colors.white, fontSize: 12),
      items: result.alternativeMatches.map((Movie m) {
        return DropdownMenuItem<Movie>(
          value: m,
          child: Text('${m.title} (${m.releaseDate.split('-').first}) - ${m.isMovie ? 'Movie' : 'TV'}', overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (Movie? newValue) {
        if (newValue != null) {
          result.matchedMovie = newValue;
          // Force UI update
          context.read<WatchlistImportProvider>().notifyListeners();
        }
      },
    );
  }

  Widget _buildLeading() {
    if (result.matchedMovie == null || result.matchedMovie!.posterPath.isEmpty) {
      return Container(
        width: 50,
        height: 75,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.movie, color: Colors.white24),
      );
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: result.matchedMovie!.posterPath,
        width: 50,
        height: 75,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => Container(
          width: 50,
          height: 75,
          color: Colors.grey[900],
          child: const Icon(Icons.broken_image, color: Colors.white24),
        ),
      ),
    );
  }

  Widget _buildTrailing() {
    if (result.status == MatchStatus.notFound) {
      return const Icon(Icons.error_outline, color: Colors.redAccent);
    }
    
    if (result.status == MatchStatus.duplicate) {
      return const Icon(Icons.copy, color: Colors.orange);
    }

    return Checkbox(
      value: result.isSelected,
      onChanged: (_) => onToggle(),
      activeColor: AppColors.primary,
    );
  }
}
