import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:watch_track/core/constants/app_colors.dart';

class PremiumSplashScreen extends StatefulWidget {
  const PremiumSplashScreen({super.key});

  @override
  State<PremiumSplashScreen> createState() => _PremiumSplashScreenState();
}

class _PremiumSplashScreenState extends State<PremiumSplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _shimmerAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Color(0xFF1E1E1E), // Premium dark grey / charcoal
              Color(0xFF0C0C0C), // Deep black-grey
              Color(0xFF000000), // Pure black
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        final shimmerPos = (_shimmerAnimation.value + 2.0) / 4.0;
                        return LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.15),
                            Colors.white,
                            AppColors.primary,
                            Colors.white,
                            Colors.white.withOpacity(0.15),
                          ],
                          stops: [
                            (shimmerPos - 0.35).clamp(0.0, 1.0),
                            (shimmerPos - 0.15).clamp(0.0, 1.0),
                            shimmerPos.clamp(0.0, 1.0),
                            (shimmerPos + 0.15).clamp(0.0, 1.0),
                            (shimmerPos + 0.35).clamp(0.0, 1.0),
                          ],
                        ).createShader(bounds);
                      },
                      child: const Icon(
                        Icons.movie_creation_rounded,
                        color: Colors.white,
                        size: 110,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  FadeTransition(
                    opacity: _controller.drive(CurveTween(curve: const Interval(0.6, 1.0))),
                    child: Column(
                      children: [
                        Text(
                          'TRACK-N-TUBE',
                          style: GoogleFonts.stixTwoText(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 8,
                            shadows: [
                              Shadow(
                                color: AppColors.primary.withOpacity(0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'LUXURY EDITION',
                          style: GoogleFonts.dmSans(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 6,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.55),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
