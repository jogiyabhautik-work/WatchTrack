import 'dart:math' as math;
import 'package:flutter/material.dart';

class MangaPageFlip extends StatefulWidget {
  final Widget front;
  final Widget back;
  final bool isFlipped;
  final Duration duration;

  const MangaPageFlip({
    super.key,
    required this.front,
    required this.back,
    this.isFlipped = false,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  State<MangaPageFlip> createState() => _MangaPageFlipState();
}

class _MangaPageFlipState extends State<MangaPageFlip> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuart),
    );
    if (widget.isFlipped) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(MangaPageFlip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != oldWidget.isFlipped) {
      if (widget.isFlipped) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final double value = _animation.value;
        final bool isFrontVisible = value < 0.5;
        
        // Calculate rotation
        // 0 to 0.5 -> 0 to 90 degrees
        // 0.5 to 1.0 -> 270 to 360 degrees (showing the back)
        double rotation = value * math.pi;
        
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateY(rotation),
          alignment: Alignment.center,
          child: isFrontVisible
              ? widget.front
              : Transform(
                  transform: Matrix4.identity()..rotateY(math.pi),
                  alignment: Alignment.center,
                  child: widget.back,
                ),
        );
      },
    );
  }
}

class MangaFlipView extends StatefulWidget {
  final List<Widget> pages;
  final Function(int)? onPageChanged;

  const MangaFlipView({
    super.key,
    required this.pages,
    this.onPageChanged,
  });

  @override
  State<MangaFlipView> createState() => _MangaFlipViewState();
}

class _MangaFlipViewState extends State<MangaFlipView> {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  double _currentPage = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page!;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: widget.onPageChanged,
      itemCount: widget.pages.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        // Calculate transform based on distance from current page
        double difference = index - _currentPage;
        
        // 3D Flip effect
        double rotation = difference * 0.4; // subtle rotation
        double scale = 1.0 - (difference.abs() * 0.1);
        double opacity = 1.0 - (difference.abs() * 0.3).clamp(0.0, 1.0);

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(rotation)
            ..scale(scale),
          alignment: Alignment.center,
          child: Opacity(
            opacity: opacity,
            child: widget.pages[index],
          ),
        );
      },
    );
  }
}
