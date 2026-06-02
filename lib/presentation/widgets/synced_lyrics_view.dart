import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:watch_track/core/providers/lyrics_provider.dart';
import 'package:watch_track/core/providers/synced_lyrics_model.dart';

class SyncedLyricsView extends StatefulWidget {
  final Duration position;
  final double? height;
  final void Function(Duration timestamp)? onSeek;

  const SyncedLyricsView({
    super.key,
    required this.position,
    this.height,
    this.onSeek,
  });

  @override
  State<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<SyncedLyricsView> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  int _lastActiveIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActive(int activeIndex) {
    if (!mounted || activeIndex < 0 || activeIndex == _lastActiveIndex) return;

    final context = _lineKeys[activeIndex]?.currentContext;
    if (context == null) return;

    _lastActiveIndex = activeIndex;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.35,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lyricsState = context.watch<LyricsProvider>().state;

    return SizedBox(
      height: widget.height,
      child: _buildContent(context, lyricsState),
    );
  }

  Widget _buildContent(BuildContext context, LyricsState state) {
    switch (state.status) {
      case LyricsStatus.idle:
        return const SizedBox.shrink();
      case LyricsStatus.loading:
        return const _LyricsMessage(
          icon: Icons.lyrics_rounded,
          message: 'Loading lyrics...',
          showSpinner: true,
        );
      case LyricsStatus.notFound:
        return const _LyricsMessage(
          icon: Icons.music_off_rounded,
          message: 'No lyrics found',
        );
      case LyricsStatus.error:
        return const _LyricsMessage(
          icon: Icons.error_outline_rounded,
          message: 'Could not load lyrics',
        );
      case LyricsStatus.loaded:
        if (!state.hasLyrics) {
          return const _LyricsMessage(
            icon: Icons.music_off_rounded,
            message: 'No lyrics available',
          );
        }
        return _buildLyricsList(state.lyrics!);
    }
  }

  Widget _buildLyricsList(SyncedLyrics lyrics) {
    final activeIndex = lyrics.currentLineIndex(widget.position);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (lyrics.isSynced) _scrollToActive(activeIndex);
    });

    return ShaderMask(
      shaderCallback: (rect) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: const [0.0, 0.08, 0.92, 1.0],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 28),
        itemCount: lyrics.lines.length,
        itemBuilder: (context, index) {
          _lineKeys[index] ??= GlobalKey();

          final line = lyrics.lines[index];
          final isActive = lyrics.isSynced && index == activeIndex;
          final isPast = lyrics.isSynced && index < activeIndex;

          return _LyricLineWidget(
            key: _lineKeys[index],
            line: line,
            isActive: isActive,
            isPast: isPast,
            isSynced: lyrics.isSynced,
            onTap: widget.onSeek != null && lyrics.isSynced
                ? () => widget.onSeek!(line.timestamp)
                : null,
          );
        },
      ),
    );
  }
}

class _LyricsMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool showSpinner;

  const _LyricsMessage({
    required this.icon,
    required this.message,
    this.showSpinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            Icon(icon, size: 40, color: Colors.white38),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LyricLineWidget extends StatelessWidget {
  final LyricLine line;
  final bool isActive;
  final bool isPast;
  final bool isSynced;
  final VoidCallback? onTap;

  const _LyricLineWidget({
    super.key,
    required this.line,
    required this.isActive,
    required this.isPast,
    required this.isSynced,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    final FontWeight fontWeight;
    final double fontSize;

    if (!isSynced) {
      textColor = Colors.white.withValues(alpha: 0.86);
      fontWeight = FontWeight.w500;
      fontSize = 18;
    } else if (isActive) {
      textColor = Colors.white;
      fontWeight = FontWeight.w800;
      fontSize = 22;
    } else if (isPast) {
      textColor = Colors.white.withValues(alpha: 0.32);
      fontWeight = FontWeight.w500;
      fontSize = 18;
    } else {
      textColor = Colors.white.withValues(alpha: 0.56);
      fontWeight = FontWeight.w500;
      fontSize = 18;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(vertical: isActive ? 10 : 7),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          style: TextStyle(
            color: textColor,
            fontWeight: fontWeight,
            fontSize: fontSize,
            height: 1.35,
          ),
          child: Text(line.text),
        ),
      ),
    );
  }
}
