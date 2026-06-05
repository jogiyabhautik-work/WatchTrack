import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:watch_track/core/theme/theme_provider.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/core/providers/auth_provider.dart';
import 'package:watch_track/core/providers/user_data_provider.dart';
import 'package:watch_track/core/providers/tracking_provider.dart';
import 'package:watch_track/presentation/screens/watchlist/watchlist_detail_screen.dart';
import 'package:watch_track/data/models/user_title_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:watch_track/presentation/screens/profile/edit_profile_screen.dart';
import 'package:watch_track/presentation/screens/profile/about_screen.dart';
import 'package:watch_track/presentation/screens/profile/account_settings_screen.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _handleRefresh() async {
    final tracking = context.read<TrackingProvider>();
    final userData = context.read<UserDataProvider>();
    await tracking.refresh();
    await userData.syncFromAppwrite();
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final surface = Theme.of(context).colorScheme.surface;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.6, -0.8),
                  radius: 1.2,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
          
          Consumer2<AuthProvider, UserDataProvider>(
            builder: (context, auth, userData, child) {
              return RefreshIndicator(
                onRefresh: _handleRefresh,
                backgroundColor: surface,
                color: AppColors.primary,
                displacement: 40,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOP SECTION
                    _buildTopSection(context, auth, userData),
    
                    const SizedBox(height: 24),

                    // ANALYTICS DASHBOARD
                    _buildAnalyticsDashboard(context),

                    const SizedBox(height: 32),
    
                    // LIBRARY SECTIONS
                    _buildLibrarySections(context),
    
                    const SizedBox(height: 24),
    
                    // PREFERENCES SECTION
                    _buildPreferencesSection(context),
    
                    const SizedBox(height: 32),
    
                    // LOG OUT BUTTON
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => auth.logout(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary, width: 0.5),
                            foregroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            'LOG OUT',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
        ],
      ),
    );
  }

  Widget _buildTopSection(BuildContext context, AuthProvider auth, UserDataProvider userData) {
    final user = auth.user;
    final tracking = context.watch<TrackingProvider>();
    final watchedCount = tracking.trackedTitles.values.where((t) => t.status == TrackingStatus.watched).length;
    final watchingCount = tracking.trackedTitles.values.where((t) => t.status == TrackingStatus.watching).length;
    final watchlistCount = tracking.trackedTitles.values.where((t) => t.status == TrackingStatus.watchlist).length;
    final likedCount = tracking.trackedTitles.values.where((t) => t.isFavorite).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: GestureDetector(
                  onTap: () => _showPfpPicker(context, userData),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        child: ClipOval(
                          child: userData.pfpUrl != null
                              ? SvgPicture.network(
                                  userData.pfpUrl!,
                                  width: 70,
                                  height: 70,
                                  placeholderBuilder: (context) => const CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Image(
                                  image: CachedNetworkImageProvider(
                                      'https://i.pravatar.cc/150?u=${user?.$id ?? 'user'}'),
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? 'Anonymous User',
                      style: GoogleFonts.dmSans(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? 'Free Member',
                      style: GoogleFonts.dmSans(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    if (user != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Member since ${DateFormat.yMMMd().format(DateTime.parse(user.registration))}',
                        style: GoogleFonts.dmSans(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (user != null && !user.emailVerification) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final success = await auth.sendEmailVerification();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success ? 'Verification email sent!' : (auth.error ?? 'Error sending email')),
                                backgroundColor: success ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange),
                              SizedBox(width: 4),
                              Text('Unverified (Tap to verify)', style: TextStyle(color: Colors.orange, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              _buildStat(watchedCount.toString(), 'Watched'),
              _buildDivider(),
              _buildStat(watchingCount.toString(), 'Watching'),
              _buildDivider(),
              _buildStat(watchlistCount.toString(), 'Saved'),
              _buildDivider(),
              _buildStat(likedCount.toString(), 'Liked'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.dmSans(
              color: AppColors.primary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.dmSans(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 0.5,
      height: 30,
      color: Theme.of(context).brightness == Brightness.dark ? AppColors.borderDefault : Colors.grey.shade300,
    );
  }

  Widget _buildAnalyticsDashboard(BuildContext context) {
    final tracking = context.watch<TrackingProvider>();
    final allItems = tracking.trackedTitles.values.toList();
    
    // Calculations
    final watched = allItems.where((t) => t.status == TrackingStatus.watched).toList();
    final totalEpisodes = watched.fold(0, (sum, item) => sum + item.lastEpisode);
    final totalHours = (totalEpisodes * 24) / 60; // Assuming 24 mins per episode
    
    final completionRate = allItems.isEmpty ? 0.0 : (watched.length / allItems.length);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
              width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Text(
                  'BINGE ANALYTICS',
                  style: GoogleFonts.dmSans(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAnalyticsItem(
                  '${totalHours.toStringAsFixed(1)}h',
                  'TIME INVESTED',
                  Icons.access_time_rounded,
                ),
                _buildAnalyticsItem(
                  '${(completionRate * 100).toInt()}%',
                  'COMPLETION',
                  Icons.check_circle_outline_rounded,
                ),
                _buildAnalyticsItem(
                  watched.length.toString(),
                  'TITLES DONE',
                  Icons.auto_awesome_motion_rounded,
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'LOYALTY LEVEL: BINGE MASTER',
                      style: GoogleFonts.dmSans(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'XP: ${watched.length * 100}/1000',
                      style: GoogleFonts.dmSans(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (watched.length % 10) / 10,
                    backgroundColor: Colors.white10,
                    color: AppColors.primary,
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 16),
        const SizedBox(height: 12),
        Text(
          value,
          style: GoogleFonts.playfairDisplay(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildLibrarySections(BuildContext context) {
    final tracking = context.watch<TrackingProvider>();
    
    final watching = tracking.trackedTitles.values.where((t) => t.status == TrackingStatus.watching).toList();
    final watched = tracking.trackedTitles.values.where((t) => t.status == TrackingStatus.watched).toList();
    final favorites = tracking.trackedTitles.values.where((t) => t.isFavorite).toList();

    return Column(
      children: [
        if (favorites.isNotEmpty) _buildLibraryCarousel(context, 'MY FAVORITES', favorites),
        if (watching.isNotEmpty) _buildLibraryCarousel(context, 'CURRENTLY WATCHING', watching),
        if (watched.isNotEmpty) _buildLibraryCarousel(context, 'RECENTLY WATCHED', watched),
      ],
    );
  }

  Widget _buildLibraryCarousel(BuildContext context, String title, List<UserTitle> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            title,
            style: GoogleFonts.dmSans(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildLibraryItem(context, item);
            },
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildLibraryItem(BuildContext context, UserTitle title) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => WatchlistDetailScreen(tmdbId: title.tmdbId)),
        );
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: title.posterPath,
                    width: 100,
                    height: 130,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Theme.of(context).colorScheme.surface),
                  ),
                  if (title.status == TrackingStatus.watching)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        value: title.progressPercent / 100,
                        backgroundColor: Colors.black26,
                        color: AppColors.primary,
                        minHeight: 3,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title.title,
              style: GoogleFonts.dmSans(color: Theme.of(context).colorScheme.onSurface, fontSize: 11, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(
              'ACCOUNT',
              style: GoogleFonts.dmSans(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildPreferenceTile(
            icon: Icons.person_outline,
            title: 'Edit Profile',
            trailing: const Icon(Icons.arrow_forward_ios, color: AppColors.textMuted, size: 14),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen()));
            },
          ),
          _buildPreferenceTile(
            icon: Icons.security_outlined,
            title: 'Account Settings',
            trailing: const Icon(Icons.arrow_forward_ios, color: AppColors.textMuted, size: 14),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountSettingsScreen()));
            },
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(
              'PREFERENCES',
              style: GoogleFonts.dmSans(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildPreferenceTile(
            context: context,
            icon: Icons.dark_mode_outlined,
            title: 'Dark Mode',
            onTap: () => context.read<ThemeProvider>().toggleTheme(),
            trailing: Consumer<ThemeProvider>(
              builder: (context, theme, child) => Switch(
                value: theme.isDarkMode,
                onChanged: (v) => theme.toggleTheme(),
                activeThumbColor: AppColors.primary,
              ),
            ),
          ),
          _buildPreferenceTile(
            context: context,
            icon: Icons.info_outline,
            title: 'About Track & Tube',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutScreen()));
            },
            trailing: Icon(Icons.arrow_forward_ios, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), size: 14),
          ),

        ],
      ),
    );
  }

  Widget _buildPreferenceTile({
    BuildContext? context,
    required IconData icon,
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final textMuted = context != null ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6) : AppColors.textMuted;
    final text = context != null ? Theme.of(context).colorScheme.onSurface : Colors.white;
    final border = context != null 
        ? (Theme.of(context).brightness == Brightness.dark ? AppColors.borderDefault : Colors.grey.shade300)
        : AppColors.borderDefault;

    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: Icon(icon, color: textMuted, size: 18),
          title: Text(
            title,
            style: GoogleFonts.dmSans(color: text, fontSize: 14),
          ),
          trailing: trailing,
        ),
        Divider(color: border, height: 0.5),
      ],
    );
  }

  void _showPfpPicker(BuildContext context, UserDataProvider userData) {
    final styles = [
      {'name': 'Avatars', 'style': 'avataaars'},
      {'name': 'Robots', 'style': 'bottts'},
      {'name': 'Pixels', 'style': 'pixel-art'},
      {'name': 'Smile', 'style': 'big-smile'},
      {'name': 'Adventurer', 'style': 'adventurer'},
      {'name': 'Lorelei', 'style': 'lorelei'},
      {'name': 'Identicon', 'style': 'identicon'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CHOOSE AVATAR STYLE',
                style: GoogleFonts.dmSans(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: styles.length,
                  itemBuilder: (context, index) {
                    final style = styles[index];
                    final previewUrl =
                        'https://api.dicebear.com/7.x/${style['style']}/svg?seed=TrackTube';

                    return GestureDetector(
                      onTap: () {
                        // Generate a random seed for variety
                        final seed = DateTime.now().millisecondsSinceEpoch.toString();
                        final finalUrl =
                            'https://api.dicebear.com/7.x/${style['style']}/svg?seed=$seed';
                        userData.updatePfp(finalUrl);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 90,
                        margin: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 50,
                              height: 50,
                              child: SvgPicture.network(previewUrl),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              style['name']!,
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Tip: Tap a style to generate a unique random avatar!',
                style: GoogleFonts.dmSans(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

}
