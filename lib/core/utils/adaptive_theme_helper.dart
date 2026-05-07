import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdaptiveThemeHelper {
  static Future<Color> getAccentColor(String imageUrl, Color fallback) async {
    try {
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(imageUrl),
        maximumColorCount: 10,
      );
      
      // Try to get a vibrant color first, then dominant
      return paletteGenerator.vibrantColor?.color ?? 
             paletteGenerator.dominantColor?.color ?? 
             fallback;
    } catch (e) {
      return fallback;
    }
  }

  static Future<PaletteGenerator?> getPalette(String imageUrl) async {
    try {
      return await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(imageUrl),
      );
    } catch (e) {
      return null;
    }
  }
}
