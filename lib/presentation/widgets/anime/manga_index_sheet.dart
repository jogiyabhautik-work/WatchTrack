import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MangaIndexSheet extends StatelessWidget {
  final List<String> categories;
  final Function(int) onCategorySelected;

  const MangaIndexSheet({
    super.key,
    required this.categories,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black, width: 8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'INDEX / 目次',
                style: GoogleFonts.stixTwoText(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.black, size: 30),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 2, color: Colors.black26),
          const SizedBox(height: 24),
          ...List.generate(categories.length, (index) {
            return _buildIndexItem(
              index + 1,
              categories[index],
              () {
                onCategorySelected(index);
                Navigator.pop(context);
              },
            );
          }),
          const SizedBox(height: 24),
          _buildIndexItem(0, 'SURPRISE ME', () {
            // Random action
            Navigator.pop(context);
          }, isSpecial: true),
        ],
      ),
    );
  }

  Widget _buildIndexItem(int chapter, String title, VoidCallback onTap, {bool isSpecial = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                chapter == 0 ? '??' : chapter.toString().padLeft(2, '0'),
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isSpecial ? Colors.red : Colors.black45,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isSpecial ? Colors.red : Colors.black,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward, size: 18, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}
