import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/core/providers/tracking_provider.dart';
import 'package:watch_track/data/models/movie_model.dart';
import 'package:watch_track/data/models/user_title_model.dart';

class TrackingBottomSheet extends StatefulWidget {
  final Movie movie;

  const TrackingBottomSheet({super.key, required this.movie});

  @override
  State<TrackingBottomSheet> createState() => _TrackingBottomSheetState();
}

class _TrackingBottomSheetState extends State<TrackingBottomSheet> {
  late UserTitle? _tracking;
  late TrackingStatus _selectedStatus;
  late double _progress;
  late double _rating;


  @override
  void initState() {
    super.initState();
    _tracking = context.read<TrackingProvider>().getTracking(int.tryParse(widget.movie.id) ?? 0);
    _selectedStatus = _tracking?.status ?? TrackingStatus.watchlist;
    _progress = (_tracking?.progressPercent ?? 0).toDouble();
    _rating = _tracking?.userRating ?? 0.0;
  }

  Widget _buildSyncIndicator(SyncStatus status) {
    IconData icon;
    Color color;
    String label;

    switch (status) {
      case SyncStatus.synced:
        icon = Icons.cloud_done_rounded;
        color = Colors.green;
        label = 'Synced';
        break;
      case SyncStatus.pending:
        icon = Icons.cloud_queue_rounded;
        color = Colors.orange;
        label = 'Pending sync';
        break;
      case SyncStatus.syncing:
        icon = Icons.sync_rounded;
        color = AppColors.primary;
        label = 'Syncing...';
        break;
      case SyncStatus.failed:
        icon = Icons.cloud_off_rounded;
        color = Colors.red;
        label = 'Sync failed';
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == SyncStatus.syncing)
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          )
        else
          Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.dmSans(color: color, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for tracking changes to update sync status in UI
    final currentTracking = context.watch<TrackingProvider>().getTracking(int.tryParse(widget.movie.id) ?? 0);
    if (currentTracking != null) {
      _tracking = currentTracking;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TRACK PROGRESS',
                style: GoogleFonts.dmSans(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_tracking != null)
                _buildSyncIndicator(_tracking!.syncStatus),
            ],
          ),
          const SizedBox(height: 20),
          
          // STATUS SELECTOR
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: TrackingStatus.values.map((status) {
                final isSelected = _selectedStatus == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(status.displayName),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedStatus = status);
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    labelStyle: GoogleFonts.dmSans(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),
          
          // PROGRESS SLIDER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PROGRESS',
                style: GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_progress.toInt()}%',
                style: GoogleFonts.dmSans(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: _progress,
            min: 0,
            max: 100,
            divisions: 100,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.surface,
            onChanged: (val) => setState(() => _progress = val),
          ),

          if (!widget.movie.isMovie && _tracking != null && _tracking!.watchedEpisodes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.playlist_add_check_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_tracking!.watchedEpisodes.length} Episodes Watched',
                        style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      'S${_tracking!.lastSeason} E${_tracking!.lastEpisode}',
                      style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // RATING SLIDER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'YOUR RATING',
                style: GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Text(
                _rating == 0 ? 'Not Rated' : _rating.toStringAsFixed(1),
                style: GoogleFonts.dmSans(color: AppColors.ratingGold, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: _rating,
            min: 0,
            max: 10,
            divisions: 20,
            activeColor: AppColors.ratingGold,
            inactiveColor: AppColors.surface,
            onChanged: (val) => setState(() => _rating = val),
          ),

          const SizedBox(height: 32),

          // SAVE BUTTON
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                context.read<TrackingProvider>().updateStatus(
                  widget.movie,
                  _selectedStatus,
                  progress: _progress.toInt(),
                  rating: _rating == 0 ? null : _rating,
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'SAVE CHANGES',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
