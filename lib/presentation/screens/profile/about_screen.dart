import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watch_track/core/constants/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchWebsite() async {
    final Uri url = Uri.parse('https://tracktube.app'); // Placeholder URL
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Professional theme handling for this screen
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final surface = Theme.of(context).colorScheme.surface;
    final text = Theme.of(context).colorScheme.onSurface;
    final textMuted = text.withValues(alpha: 0.6);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('About', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: text)),
        backgroundColor: surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              color: surface,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset('assets/logo/logo.png', height: 110, width: 110),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Track & Tube',
                    style: GoogleFonts.playfairDisplay(
                      color: text,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'track . tube . enjoy',
                    style: GoogleFonts.dmSans(
                      color: AppColors.primary,
                      fontSize: 14,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Version 1.0.0',
                    style: GoogleFonts.dmSans(
                      color: textMuted,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Track & Tube is your ultimate cinematic companion. Whether you are discovering your next favorite movie, organizing your binge-watching schedule, or diving into iconic soundtracks, we bring the magic of the movies directly to your hands.',
                    style: GoogleFonts.dmSans(
                      color: text,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: _launchWebsite,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.language, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Visit our official website',
                            style: GoogleFonts.dmSans(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'WHY TRACK & TUBE?',
                    style: GoogleFonts.dmSans(
                      color: AppColors.primary,
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureRow(
                    context,
                    Icons.dashboard_customize_rounded,
                    'Smart Watchlists',
                    'Organize your movies and shows with custom folders and easy sorting.',
                    text,
                    textMuted,
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureRow(
                    context,
                    Icons.music_note_rounded,
                    'Iconic Soundtracks',
                    'Listen to the official scores and soundtracks of your favorite films.',
                    text,
                    textMuted,
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureRow(
                    context,
                    Icons.analytics_rounded,
                    'Binge Analytics',
                    'Track your watching habits and see your cinematic journey grow.',
                    text,
                    textMuted,
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Footer section
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.movie_filter_rounded, color: AppColors.primary, size: 32),
                        const SizedBox(height: 16),
                        Text(
                          'Built by cinema lovers, for cinema lovers.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.playfairDisplay(
                            color: text,
                            fontSize: 18,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Developed by Bhautik & Jatin',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '© 2026 Track & Tube. All rights reserved.',
                          style: GoogleFonts.dmSans(
                            color: textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(BuildContext context, IconData icon, String title, String desc, Color text, Color textMuted) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.dmSans(
                  color: text,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: GoogleFonts.dmSans(
                  color: textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
