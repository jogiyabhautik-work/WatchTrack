import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:watch_track/core/constants/app_colors.dart';

class BingePlannerWidget extends StatefulWidget {
  const BingePlannerWidget({super.key});

  @override
  State<BingePlannerWidget> createState() => _BingePlannerWidgetState();
}

class _BingePlannerWidgetState extends State<BingePlannerWidget> {
  double _episodesPerDay = 3.0;
  int _totalEpisodes = 24;

  @override
  Widget build(BuildContext context) {
    int daysToFinish = (_totalEpisodes / _episodesPerDay).ceil();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderDefault, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'BINGE PLANNER',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Total Episodes',
            style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 11),
          ),
          Slider(
            value: _totalEpisodes.toDouble(),
            min: 1,
            max: 100,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.surface2,
            onChanged: (v) => setState(() => _totalEpisodes = v.toInt()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1', style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 10)),
              Text('$_totalEpisodes eps', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
              Text('100', style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Episodes per Day',
            style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 11),
          ),
          Slider(
            value: _episodesPerDay,
            min: 1,
            max: 24,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.surface2,
            onChanged: (v) => setState(() => _episodesPerDay = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1', style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 10)),
              Text('${_episodesPerDay.toInt()} eps/day', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
              Text('24', style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
          const Divider(height: 40, color: AppColors.borderDefault),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: AppColors.primary),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ESTIMATED COMPLETION',
                      style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.primary),
                    ),
                    Text(
                      '$daysToFinish DAYS',
                      style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
