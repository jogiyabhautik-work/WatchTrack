import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/presentation/screens/video/custom_stream_player.dart';
import 'package:watch_track/core/services/download_progress_notifier.dart';

class DownloadDetailScreen extends StatefulWidget {
  final File file;
  const DownloadDetailScreen({Key? key, required this.file}) : super(key: key);

  @override
  State<DownloadDetailScreen> createState() => _DownloadDetailScreenState();
}

class _DownloadDetailScreenState extends State<DownloadDetailScreen> {
  double _progress = 0.0;
  String get _fileName => widget.file.path.split('/').last.replaceAll('.mp4', '').replaceAll('_', ' ');

  @override
  void initState() {
    super.initState();
    final key = widget.file.path;
    // Register listener for progress updates
    DownloadProgressNotifier().addListener(_updateProgress);
    // Initialize with any existing progress
    _progress = DownloadProgressNotifier().getProgress(key) ?? 0.0;
  }

  @override
  void dispose() {
    DownloadProgressNotifier().removeListener(_updateProgress);
    super.dispose();
  }

  void _updateProgress() {
    final key = widget.file.path;
    final prog = DownloadProgressNotifier().getProgress(key);
    if (prog != null && prog != _progress) {
      setState(() => _progress = prog);
    }
  }

  String get _fileSize {
    try {
      final size = widget.file.statSync().size / (1024 * 1024);
      return '${size.toStringAsFixed(1)} MB';
    } catch (_) {
      return 'Unknown Size';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Download Details', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_fileName, style: GoogleFonts.dmSans(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_fileSize, style: GoogleFonts.dmSans(color: AppColors.textMuted)),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: AppColors.borderDefault,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 6,
            ),
            const SizedBox(height: 12),
            Text('${(_progress * 100).toStringAsFixed(0)}%', style: GoogleFonts.dmSans(color: Colors.white70)),
            const Spacer(),
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.play_arrow, color: Colors.white),
                label: Text('Play', style: GoogleFonts.dmSans(color: Colors.white)),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CustomStreamPlayer(url: widget.file.path, title: _fileName)));
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
