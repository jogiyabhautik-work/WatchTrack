// ignore_for_file: deprecated_member_use, avoid_print, unused_element, experimental_member_use
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class YoutubeAudioSource extends StreamAudioSource {
  final String url;
  final MediaItem mediaItem;

  YoutubeAudioSource({
    required this.url,
    required this.mediaItem,
  }) : super(tag: mediaItem);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    try {
      final request = http.Request('GET', Uri.parse(url));
      if (end != null) {
        request.headers['Range'] = 'bytes=$start-$end';
      } else {
        request.headers['Range'] = 'bytes=$start-';
      }

      request.headers['User-Agent'] = 
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

      debugPrint('Proxy requesting: Range bytes=$start-${end ?? ""}');
      final response = await http.Client().send(request);
      debugPrint('Proxy response: ${response.statusCode}');
      
      if (response.statusCode >= 400) {
        debugPrint('Proxy error body: ${await response.stream.bytesToString()}');
        throw Exception('HTTP Error ${response.statusCode}');
      }

      int? totalLength;
      final contentRange = response.headers['content-range'];
      if (contentRange != null) {
        final parts = contentRange.split('/');
        if (parts.length == 2) {
          totalLength = int.tryParse(parts[1]);
        }
      } else {
        final contentLength = response.headers['content-length'];
        if (contentLength != null) {
          totalLength = int.tryParse(contentLength);
          if (totalLength != null) {
            totalLength += start;
          }
        }
      }

      return StreamAudioResponse(
        sourceLength: totalLength,
        contentLength: response.contentLength,
        offset: start,
        stream: response.stream,
        contentType: response.headers['content-type'] ?? 'audio/mp4',
      );
    } catch (e) {
      debugPrint('Proxy Exception: $e');
      rethrow;
    }
  }
}

