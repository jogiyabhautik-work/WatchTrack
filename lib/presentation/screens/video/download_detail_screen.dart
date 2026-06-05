import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/presentation/screens/video/advanced_video_player.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:ui';

class DownloadDetailScreen extends StatelessWidget {
  final String filePath;
  final String title;

  const DownloadDetailScreen({
    super.key,
    required this.filePath,
    required this.title,
  });

  void _playVideo(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdvancedVideoPlayer(
          url: filePath,
          title: title,
        ),
      ),
    );
  }

  void _deleteVideo(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete Download?', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this downloaded video?', style: GoogleFonts.dmSans(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.dmSans(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.dmSans(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
        
        // Remove from index
        final appDir = await getApplicationDocumentsDirectory();
        final trackDir = Directory('${appDir.path}/TrackAndTube');
        final indexFile = File('${trackDir.path}/download_index.json');
        
        if (await indexFile.exists()) {
          final content = await indexFile.readAsString();
          final Map<String, dynamic> index = content.isNotEmpty ? jsonDecode(content) : {};
          final safeTitle = title.replaceAll(RegExp(r'[^\w\s]+'), '').trim().replaceAll(' ', '_');
          if (index.containsKey(safeTitle)) {
            index.remove(safeTitle);
            await indexFile.writeAsString(jsonEncode(index));
          }
        }
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download deleted'), backgroundColor: Colors.redAccent)
          );
          Navigator.pop(context); // Go back
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting: $e'), backgroundColor: Colors.redAccent)
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Downloaded Video', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Gradient matching app theme
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Colors.black],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  
                  // Glassmorphism Card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Icon(Icons.video_library_rounded, size: 64, color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            Text(
                              title,
                              style: GoogleFonts.dmSans(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 8),
                            
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
                                const SizedBox(width: 6),
                                Text('Downloaded to Local Storage', style: GoogleFonts.dmSans(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 24),
                            
                            FutureBuilder<FileStat>(
                              future: File(filePath).stat(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  final sizeMB = snapshot.data!.size / (1024 * 1024);
                                  return Text('File Size: ${sizeMB.toStringAsFixed(2)} MB', style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 13));
                                }
                                return const SizedBox();
                              }
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: () => _playVideo(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF8B5CF6)]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                                const SizedBox(width: 8),
                                Text('Play Now', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: GestureDetector(
                          onTap: () => _deleteVideo(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.1),
                              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
