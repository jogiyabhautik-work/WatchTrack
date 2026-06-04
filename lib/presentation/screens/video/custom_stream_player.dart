import 'package:flutter/material.dart';
import 'package:watch_track/presentation/screens/video/advanced_video_player.dart';
import 'package:watch_track/core/services/stream_providers/stream_provider.dart';

/// Compatibility wrapper that forwards to the new [AdvancedVideoPlayer].
/// Existing codebases that instantiate `CustomStreamPlayer` will continue to work
/// without any modifications.
class CustomStreamPlayer extends StatelessWidget {
  final String url;
  final String title;
  final List<StreamQuality>? qualities;

  const CustomStreamPlayer({
    super.key,
    required this.url,
    required this.title,
    this.qualities,
  });

  @override
  Widget build(BuildContext context) {
    return AdvancedVideoPlayer(
      url: url,
      title: title,
      qualities: qualities,
    );
  }
}
