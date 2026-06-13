import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/presentation/screens/home/home_screen.dart';
import 'package:watch_track/presentation/screens/search/search_screen.dart';
import 'package:watch_track/presentation/screens/watchlist/watchlist_screen.dart';
import 'package:watch_track/presentation/screens/audio/audio_library_screen.dart';
import 'package:watch_track/presentation/widgets/mini_audio_player.dart';
import 'package:provider/provider.dart';
import 'package:watch_track/core/providers/auth_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:watch_track/features/update/presentation/widgets/update_banner.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(),
    const WatchlistScreen(),
    const AudioLibraryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.notification.request();
  }

  @override
  Widget build(BuildContext context) {
    final authStatus = context.select((AuthProvider p) => p.status);
    final isOffline = authStatus == AuthStatus.authenticatedOffline;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.black,
      body: Column(
        children: [
          const UpdateBanner(),
          Expanded(
            child: Stack(
              children: [
                IndexedStack(
                  index: _selectedIndex,
                  children: _screens,
                ),
                if (isOffline)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Container(
                        color: Colors.redAccent.withValues(alpha: 0.9),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: const Center(
                          child: Text(
                            'You are offline. Showing cached data.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniAudioPlayer(),
          _buildFloatingNavBar(),
        ],
      ),
    );
  }

  Widget _buildFloatingNavBar() {
    return Container(
      height: 90,
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home_filled, 'HOME'),
                _buildNavItem(1, Icons.search_rounded, Icons.search_rounded, 'SEARCH'),
                _buildNavItem(2, Icons.movie_filter_outlined, Icons.movie_filter_rounded, 'LIBRARY'),
                _buildNavItem(3, Icons.music_note_outlined, Icons.music_note_rounded, 'MUSIC'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.4),
              size: 26,
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
