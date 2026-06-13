import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:watch_track/features/update/data/models/update_model.dart';
import 'package:watch_track/features/update/presentation/cubit/update_cubit.dart';
import 'package:watch_track/features/update/presentation/cubit/update_state.dart';

class UpdateScreen extends StatelessWidget {
  const UpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          
          // Glassmorphism Card
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  constraints: const BoxConstraints(maxWidth: 450),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: BlocBuilder<UpdateCubit, UpdateState>(
                    builder: (context, state) {
                      if (state is UpdateAvailable) {
                        return _buildAvailableUI(context, state.update, state.isForced);
                      } else if (state is UpdateDownloading) {
                        return _buildDownloadingUI(context, state);
                      } else if (state is UpdateDownloadCompleted) {
                        return _buildCompletedUI(context);
                      } else if (state is UpdateError) {
                        return _buildErrorUI(context, state.message);
                      }
                      return const Center(child: CircularProgressIndicator());
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableUI(BuildContext context, UpdateModel update, bool isForced) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.system_update_rounded, size: 64, color: Colors.blueAccent),
        const SizedBox(height: 16),
        Text(
          'Update Available',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Version \${update.versionName} • \${update.apkSize}',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "What's New:",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: ListView.builder(
            itemCount: update.changelog.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Colors.blueAccent)),
                    Expanded(
                      child: Text(
                        update.changelog[index],
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              context.read<UpdateCubit>().startDownload();
            },
            child: const Text('Update Now', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
        if (!isForced) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ],
    );
  }

  Widget _buildDownloadingUI(BuildContext context, UpdateDownloading state) {
    final downloadedMB = (state.receivedBytes / (1024 * 1024)).toStringAsFixed(1);
    final totalMB = (state.totalBytes / (1024 * 1024)).toStringAsFixed(1);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_download_rounded, size: 64, color: Colors.blueAccent),
        const SizedBox(height: 16),
        Text(
          state.isPaused ? 'Download Paused' : 'Downloading Update',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        LinearProgressIndicator(
          value: state.progress,
          backgroundColor: Colors.white.withOpacity(0.1),
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('\${(state.progress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white)),
            Text('\$downloadedMB MB / \$totalMB MB', style: const TextStyle(color: Colors.white70)),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (state.isPaused)
              IconButton(
                onPressed: () => context.read<UpdateCubit>().resumeDownload(),
                icon: const Icon(Icons.play_circle_fill, size: 48, color: Colors.blueAccent),
              )
            else
              IconButton(
                onPressed: () => context.read<UpdateCubit>().pauseDownload(),
                icon: const Icon(Icons.pause_circle_filled, size: 48, color: Colors.orange),
              ),
            const SizedBox(width: 24),
            IconButton(
              onPressed: () => context.read<UpdateCubit>().cancelDownload(),
              icon: const Icon(Icons.cancel, size: 48, color: Colors.redAccent),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildCompletedUI(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        Text(
          'Download Complete',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'The update is ready to install.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              context.read<UpdateCubit>().installApk();
            },
            child: const Text('Install Now', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorUI(BuildContext context, String message) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
        const SizedBox(height: 16),
        Text(
          'Update Failed',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              context.read<UpdateCubit>().checkForUpdates(isManualCheck: true);
            },
            child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
