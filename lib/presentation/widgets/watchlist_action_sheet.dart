import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/core/providers/tracking_provider.dart';
import 'package:watch_track/core/providers/watchlist_folder_provider.dart';
import 'package:watch_track/data/models/user_title_model.dart';
import 'package:watch_track/data/models/movie_model.dart';

class WatchlistActionSheet extends StatelessWidget {
  final Movie movie;

  const WatchlistActionSheet({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    final folderProvider = context.read<WatchlistFolderProvider>();
    final folders = folderProvider.folders;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ──────────────────────────────────────────────────────
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Title ────────────────────────────────────────────────────────
          Text(
            'Save to Watchlist',
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            movie.title,
            style: GoogleFonts.dmSans(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),

          // ── Save without folder ──────────────────────────────────────────
          SheetTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bookmarks_outlined,
                  color: AppColors.primary, size: 20),
            ),
            title: 'Add to Watchlist',
            subtitle: 'Save without a folder',
            onTap: () {
              final tracking = context.read<TrackingProvider>();
              tracking.updateStatus(movie, TrackingStatus.watchlist);
              Navigator.pop(context);
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✓ Added to Watchlist',
                    style: GoogleFonts.dmSans(fontSize: 13),
                  ),
                  backgroundColor: AppColors.surface2,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),

          // ── Folder rows ──────────────────────────────────────────────────
          if (folders.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                      child: Divider(
                          color: Colors.white.withValues(alpha: 0.1), height: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OR SAVE TO FOLDER',
                      style: GoogleFonts.dmSans(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                      child: Divider(
                          color: Colors.white.withValues(alpha: 0.1), height: 1)),
                ],
              ),
            ),
            ...folders.map(
              (folder) => SheetTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child:
                        Text(folder.emoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
                title: folder.name,
                subtitle:
                    '${folder.movieIds.length} title${folder.movieIds.length == 1 ? '' : 's'}',
                onTap: () {
                  // 1. Add to global tracking
                  final tracking = context.read<TrackingProvider>();
                  final t = tracking.getTracking(int.tryParse(movie.id) ?? 0);
                  if (t == null) {
                    tracking.updateStatus(movie, TrackingStatus.watchlist);
                  }
                  // 2. Add movie ID to folder
                  context.read<WatchlistFolderProvider>().addToFolder(
                        id: movie.id,
                        title: movie.title,
                        posterPath: movie.posterPath,
                        isMovie: movie.isMovie,
                        folderId: folder.id,
                      );
                  Navigator.pop(context);
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '✓ Saved to ${folder.emoji} ${folder.name}',
                        style: GoogleFonts.dmSans(fontSize: 13),
                      ),
                      backgroundColor: AppColors.surface2,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class SheetTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const SheetTile({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07), width: 1),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textMuted, size: 14),
          ],
        ),
      ),
    );
  }
}
