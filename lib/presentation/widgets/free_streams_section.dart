import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/data/models/movie_model.dart';
import 'package:watch_track/core/services/stream_providers/stream_provider.dart';
import 'package:watch_track/core/services/free_stream_service.dart';
import 'package:watch_track/core/services/download_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:watch_track/presentation/screens/video/download_detail_screen.dart';
import 'package:watch_track/presentation/screens/video/custom_stream_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FreeStreamsSection extends StatefulWidget {
  final Movie movie;

  const FreeStreamsSection({super.key, required this.movie});

  @override
  State<FreeStreamsSection> createState() => _FreeStreamsSectionState();
}

class _FreeStreamsSectionState extends State<FreeStreamsSection> {
  final FreeStreamService _streamService = FreeStreamService();
  final DownloadService _downloadService = DownloadService();

  List<StreamVideoData> _allStreams = [];
  List<StreamVideoData> _filteredStreams = [];
  List<String> _availableLanguages = [];
  String _selectedLanguage = 'All';
  
  bool _isLoading = true;
  bool _hasError = false;
  
  final Map<String, double> _downloadProgress = {};
  Set<String> _downloadedTitles = {};

  @override
  void initState() {
    super.initState();
    _fetchStreams();
    _loadDownloadedIndex();
  }

  Future<void> _fetchStreams() async {
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final streams = await _streamService.getAllAvailableStreams(widget.movie);
      
      final languages = streams.map((e) => e.language).toSet().toList();
      languages.sort();
      languages.insert(0, 'All');

      if (mounted) {
        setState(() {
          _allStreams = streams;
          _availableLanguages = languages;
          _selectedLanguage = 'All';
          _isLoading = false;
          _filterStreams();
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  Future<void> _loadDownloadedIndex() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final trackDir = Directory('${appDir.path}/TrackAndTube');
      final indexFile = File('${trackDir.path}/download_index.json');
      if (await indexFile.exists()) {
        final content = await indexFile.readAsString();
        final Map<String, dynamic> index = content.isNotEmpty ? jsonDecode(content) : {};
        setState(() {
          _downloadedTitles = index.keys.toSet();
        });
      }
    } catch (e) {
      debugPrint('Failed to load download index: $e');
    }
  }

  void _filterStreams() {
    if (_selectedLanguage == 'All') {
      _filteredStreams = List.from(_allStreams);
    } else {
      _filteredStreams = _allStreams.where((s) => s.language == _selectedLanguage).toList();
    }
  }

  void _playStream(StreamVideoData stream) {
    if (stream.qualities.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CustomStreamPlayer(
        url: stream.qualities.first.url, 
        title: stream.title,
        qualities: stream.qualities,
      ),
    ));
  }

  void _downloadStream(StreamVideoData stream) async {
    if (stream.qualities.isEmpty) return;
    if (_downloadProgress.containsKey(stream.id)) return;
    
    // Select quality and destination
    bool saveToGallery = true;
    StreamQuality? selectedQuality;
    
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Download Options', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                SwitchListTile(
                  title: Text('Save to Photo Gallery', style: GoogleFonts.dmSans(color: Colors.white)),
                  subtitle: Text('If disabled, saves to in-app library', style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 12)),
                  value: saveToGallery,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) => setModalState(() => saveToGallery = val),
                ),
                const Divider(color: Colors.white24),
                ...stream.qualities.map((q) => ListTile(
                  title: Text('Download ${q.quality}', style: GoogleFonts.dmSans(color: Colors.white)),
                  trailing: const Icon(Icons.download_rounded, color: Colors.white70),
                  onTap: () => Navigator.pop(context, {'quality': q, 'gallery': saveToGallery}),
                )),
                const SizedBox(height: 16),
              ],
            );
          }
        );
      }
    );
    
    if (result == null) return;
    selectedQuality = result['quality'];
    saveToGallery = result['gallery'];
    
    if (selectedQuality == null) return;
    
    setState(() => _downloadProgress[stream.id] = 0.0);
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Starting download for ${selectedQuality.quality}...'),
    ));

    final errorMessage = await _downloadService.startDownload(
      url: selectedQuality.url,
      title: widget.movie.title,
      saveToGallery: saveToGallery,
      youtubeVideoId: selectedQuality.youtubeVideoId,
      youtubeQualityLabel: selectedQuality.quality,
      onProgress: (progress) {
        if (mounted) {
          setState(() => _downloadProgress[stream.id] = progress);
        }
      },
    );

    if (mounted) {
      setState(() => _downloadProgress.remove(stream.id));
    }

    if (mounted) {
      final success = errorMessage == null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? (saveToGallery ? 'Video saved to App & Gallery!' : 'Video saved to Downloads!') : 'Download failed: $errorMessage'),
        backgroundColor: success ? Colors.green : Colors.redAccent,
        duration: const Duration(seconds: 4),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.primary)));
    }
    if (_hasError) {
      return const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('Failed to load streams', style: TextStyle(color: Colors.redAccent))));
    }

    if (_allStreams.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Icon(Icons.videocam_off_outlined, color: AppColors.textMuted, size: 48),
              const SizedBox(height: 12),
              Text('No free streams found matching duration.', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('FREE STREAMS', style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.w900)),
            if (_availableLanguages.length > 1)
              DropdownButton<String>(
                value: _selectedLanguage,
                dropdownColor: AppColors.surface2,
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                items: _availableLanguages.map((String lang) {
                  return DropdownMenuItem<String>(
                    value: lang,
                    child: Text(lang, style: GoogleFonts.dmSans(color: Colors.white, fontSize: 12)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() { _selectedLanguage = val; _filterStreams(); });
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        ..._filteredStreams.map((stream) {
          final isDownloading = _downloadProgress.containsKey(stream.id);
          final progress = _downloadProgress[stream.id] ?? 0.0;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderDefault, width: 0.5),
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
              leading: Container(
                width: 60,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1), 
                  borderRadius: BorderRadius.circular(8),
                  image: stream.thumbnailUrl != null ? DecorationImage(
                    image: CachedNetworkImageProvider(stream.thumbnailUrl!),
                    fit: BoxFit.cover,
                  ) : null,
                ),
                child: stream.thumbnailUrl == null 
                    ? const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary)
                    : const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 20)),
              ),
              title: Text('${stream.sourceName} • ${stream.language}', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              subtitle: Text('${stream.qualities.length} Qualities Available', style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 11)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDownloading)
                SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(value: progress, color: AppColors.primary, strokeWidth: 2),
                )
              else if (_downloadedTitles.contains(stream.title.replaceAll(RegExp(r'[^\\w\\s]+'), '').trim().replaceAll(' ', '_')))
                IconButton(
                  icon: const Icon(Icons.download_done_rounded, color: Colors.greenAccent),
                  onPressed: () async {
                    final safeTitle = stream.title.replaceAll(RegExp(r'[^\\w\\s]+'), '').trim().replaceAll(' ', '_');
                    final appDir = Directory('${(await getApplicationDocumentsDirectory()).path}/TrackAndTube');
                    final filePath = '${appDir.path}/$safeTitle.mp4';
                    if (!context.mounted) return;
                    Navigator.push(context, MaterialPageRoute(builder: (_) => DownloadDetailScreen(filePath: filePath, title: stream.title)));
                  },
                )
              else
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.white70),
                  onPressed: () => _downloadStream(stream),
                ),
              IconButton(
                icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
                onPressed: () => _playStream(stream),
              ),
            ],
          ),
              onTap: () => _playStream(stream),
            ),
            ),
          );
        }),
      ],
    );
  }
}
