import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/presentation/screens/video/custom_stream_player.dart';
import 'package:watch_track/core/services/download_progress_notifier.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<FileSystemEntity> _downloadedFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    setState(() => _isLoading = true);
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final files = appDir.listSync().where((file) => file.path.endsWith('.mp4')).toList();
      setState(() {
        _downloadedFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading downloads: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteFile(FileSystemEntity file) async {
    try {
      await file.delete();
      _loadDownloads();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File deleted')));
      }
    } catch (e) {
      debugPrint('Delete error: $e');
    }
  }

  String _getFileName(String path) {
    return path.split('/').last.replaceAll('.mp4', '').replaceAll('_', ' ');
  }

  String _getFileSize(FileSystemEntity file) {
    try {
      final stat = file.statSync();
      final mb = stat.size / (1024 * 1024);
      return '${mb.toStringAsFixed(1)} MB';
    } catch (e) {
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
        title: Text('Downloads', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _downloadedFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.download_done_rounded, color: Colors.white30, size: 64),
                      const SizedBox(height: 16),
                      Text('No in-app downloads yet.', style: GoogleFonts.dmSans(color: Colors.white70)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _downloadedFiles.length,
                  itemBuilder: (context, index) {
                    final file = _downloadedFiles[index];
                    final fileName = _getFileName(file.path);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderDefault, width: 0.5),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.movie_rounded, color: AppColors.primary),
                        ),
                        title: Text(fileName, style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(_getFileSize(file), style: GoogleFonts.dmSans(color: AppColors.textMuted)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white),
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => CustomStreamPlayer(url: file.path, title: fileName),
                                ));
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                              onPressed: () => _deleteFile(file),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
