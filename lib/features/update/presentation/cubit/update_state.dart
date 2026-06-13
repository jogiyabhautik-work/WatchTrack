import 'package:watch_track/features/update/data/models/update_model.dart';

abstract class UpdateState {}

class UpdateInitial extends UpdateState {}

class UpdateChecking extends UpdateState {}

class UpdateAvailable extends UpdateState {
  final UpdateModel update;
  final bool isForced;

  UpdateAvailable({required this.update, required this.isForced});
}

class UpdateNotAvailable extends UpdateState {}

class UpdateDownloading extends UpdateState {
  final double progress; // 0.0 to 1.0
  final int receivedBytes;
  final int totalBytes;
  final bool isPaused;

  UpdateDownloading({
    required this.progress,
    required this.receivedBytes,
    required this.totalBytes,
    this.isPaused = false,
  });
}

class UpdateDownloadCompleted extends UpdateState {}

class UpdateError extends UpdateState {
  final String message;

  UpdateError(this.message);
}
