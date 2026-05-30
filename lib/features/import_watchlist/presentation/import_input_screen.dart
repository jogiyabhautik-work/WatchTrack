import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/features/import_watchlist/presentation/watchlist_import_provider.dart';
import 'package:watch_track/features/import_watchlist/presentation/import_review_screen.dart';

class ImportInputScreen extends StatefulWidget {
  const ImportInputScreen({Key? key}) : super(key: key);

  @override
  State<ImportInputScreen> createState() => _ImportInputScreenState();
}

class _ImportInputScreenState extends State<ImportInputScreen> {
  final TextEditingController _textController = TextEditingController();

  void _navigateToReview() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ImportReviewScreen()),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Smart Watchlist Import', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Paste a list of movies or TV shows below:',
              style: GoogleFonts.dmSans(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'e.g.\n1. Oppenheimer\n2. Breaking Bad s1-s3\n3. The Batman (2022)',
                    hintStyle: GoogleFonts.dmSans(color: Colors.white24),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                if (_textController.text.trim().isNotEmpty) {
                  context.read<WatchlistImportProvider>().startImportFromText(_textController.text);
                  _navigateToReview();
                }
              },
              icon: const Icon(Icons.paste),
              label: Text('Import from Text', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider(color: Colors.white24)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('OR', style: GoogleFonts.dmSans(color: Colors.white54, fontWeight: FontWeight.bold)),
                ),
                const Expanded(child: Divider(color: Colors.white24)),
              ],
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                context.read<WatchlistImportProvider>().startImport();
                _navigateToReview();
              },
              icon: const Icon(Icons.file_upload, color: Colors.white),
              label: Text('Import from File (.txt, .csv)', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
