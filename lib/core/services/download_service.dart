import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class DownloadService {
  final Dio _dio = Dio();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> _initNotifications() async {
    if (_isInitialized) return;
    
    // Request notification permissions for Android 13+
    if (Platform.isAndroid) {
      await _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    }

    const androidInitialize = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInitialize = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(android: androidInitialize, iOS: iosInitialize);
    
    await _notificationsPlugin.initialize(settings: initializationSettings);
    _isInitialized = true;
  }

  Future<String?> startDownload({
    required String url,
    required String title,
    required bool saveToGallery,
    required Function(double) onProgress,
    String? youtubeVideoId,
    String? youtubeQualityLabel,
  }) async {
    await _initNotifications();
    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    try {
      bool canSaveToGallery = saveToGallery;
      
      if (canSaveToGallery) {
        final hasAccess = await Gal.hasAccess(toAlbum: true);
        if (!hasAccess) {
          final granted = await Gal.requestAccess(toAlbum: true);
          if (!granted) {
            canSaveToGallery = false;
          }
        }
      }

      final appDir = await getApplicationDocumentsDirectory();
      // Create dedicated Track&Tube directory inside app documents
      final trackDir = Directory('${appDir.path}/TrackAndTube');
      if (!await trackDir.exists()) {
        await trackDir.create(recursive: true);
      }
      final safeTitle = title.replaceAll(RegExp(r'[^\w\s]+'), '').trim().replaceAll(' ', '_');
      final downloadPath = '${trackDir.path}/$safeTitle.mp4';

      await _showNotification(notificationId, 'Downloading $title...', 0);

      if (url.contains('.m3u8')) {
        // Use FFmpegKit to download and convert HLS to MP4
        final session = await FFmpegKit.execute('-i "$url" -c copy "$downloadPath"');
        final returnCode = await session.getReturnCode();
        if (!ReturnCode.isSuccess(returnCode)) {
          final logs = await session.getLogsAsString();
          throw Exception('Failed to process M3U8 stream: $logs');
        }
      } else if (youtubeVideoId != null) {
        // Re-fetch a FRESH manifest at download time (old URLs expire quickly)
        final yt = YoutubeExplode();
        try {
          debugPrint('YouTube Download: Fetching fresh manifest for $youtubeVideoId');
          final manifest = await yt.videos.streamsClient.getManifest(VideoId(youtubeVideoId));
          
          // Find the best matching stream for the requested quality
          final muxedStreams = manifest.muxed.sortByVideoQuality();
          if (muxedStreams.isEmpty) {
            throw Exception('No muxed streams available for this video');
          }

          // Try to match the requested quality, fallback to best available
          var targetStream = muxedStreams.first; // default: best quality
          if (youtubeQualityLabel != null) {
            for (var s in muxedStreams) {
              if (s.videoQuality.name.toUpperCase() == youtubeQualityLabel.toUpperCase()) {
                targetStream = s;
                break;
              }
            }
          }

          debugPrint('YouTube Download: Using quality ${targetStream.videoQuality.name}, size: ${targetStream.size.totalBytes} bytes');
          
          final stream = yt.videos.streamsClient.get(targetStream);
          final totalBytes = targetStream.size.totalBytes;
          var receivedBytes = 0;
          var lastNotifiedPercent = -1;
          
          final file = File(downloadPath);
          final fileStream = file.openWrite();
          
          await for (final data in stream) {
            receivedBytes += data.length;
            fileStream.add(data);
            
            final progress = totalBytes > 0 ? receivedBytes / totalBytes : 0.0;
            final percent = (progress * 100).toInt();
            
            try {
              onProgress(progress);
            } catch (_) {}
            
            // Notify every 5%
            if (percent ~/ 5 != lastNotifiedPercent ~/ 5) {
              lastNotifiedPercent = percent;
              _showNotification(notificationId, 'Downloading $title...', percent);
            }
          }
          
          await fileStream.flush();
          await fileStream.close();
          debugPrint('YouTube Download: Complete! Saved ${receivedBytes} bytes to $downloadPath');
        } finally {
          yt.close();
        }
      } else {
        // Standard file download
        await _dio.download(
          url,
          downloadPath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              final progress = received / total;
              try {
                onProgress(progress);
              } catch (e) {
                debugPrint('onProgress error: $e');
              }
              
              if ((progress * 100).toInt() % 5 == 0) {
                _showNotification(notificationId, 'Downloading $title...', (progress * 100).toInt());
              }
            }
          },
        );
      }

      if (canSaveToGallery) {
        try {
          await Gal.putVideo(downloadPath, album: 'Track & Tube');
        } catch (galleryError) {
          debugPrint('Gallery save error: $galleryError');
        }
      }
      // Update download index for UI lookup
      try {
        final indexFile = File('${trackDir.path}/download_index.json');
        Map<String, dynamic> index = {};
        if (await indexFile.exists()) {
          final content = await indexFile.readAsString();
          index = content.isNotEmpty ? jsonDecode(content) : {};
        }
        // Use safeTitle as key for simplicity
        index[safeTitle] = downloadPath;
        await indexFile.writeAsString(jsonEncode(index));
      } catch (e) {
        debugPrint('Failed to write download index: $e');
      }

      await _showNotification(notificationId, 'Download Complete', 100, isFinished: true);
      return null; // Success
    } catch (e) {
      debugPrint('Download error: $e');
      await _showNotification(notificationId, 'Download Failed', 0, isFinished: true);
      return e.toString();
    }
  }

  Future<void> _showNotification(int id, String title, int progress, {bool isFinished = false}) async {
    final androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Downloads',
      channelDescription: 'Shows progress of video downloads',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: !isFinished,
      maxProgress: 100,
      progress: progress,
      icon: '@mipmap/launcher_icon',
      onlyAlertOnce: true,
    );
    
    final notificationDetails = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      id: id, 
      title: title, 
      body: isFinished ? 'Tap to view' : '$progress% downloaded', 
      notificationDetails: notificationDetails
    );
  }
}
