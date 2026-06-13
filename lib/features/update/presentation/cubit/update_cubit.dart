import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:watch_track/features/update/data/models/update_model.dart';
import 'package:watch_track/features/update/data/repositories/update_repository.dart';
import 'package:watch_track/features/update/domain/download_manager.dart';
import 'package:watch_track/features/update/domain/version_comparator.dart';
import 'update_state.dart';

class UpdateCubit extends Cubit<UpdateState> {
  final UpdateRepository _repository;
  final DownloadManager _downloadManager;
  UpdateModel? _currentUpdate;

  UpdateCubit(this._repository)
      : _downloadManager = DownloadManager(),
        super(UpdateInitial());

  Future<void> checkForUpdates({bool isManualCheck = false}) async {
    emit(UpdateChecking());
    try {
      final update = await _repository.getLatestUpdate();
      if (update == null) {
        emit(UpdateNotAvailable());
        return;
      }

      final isAvailable = await VersionComparator.isUpdateAvailable(update.versionCode);
      if (isAvailable) {
        _currentUpdate = update;
        final isForced = await VersionComparator.isForceUpdate(update.minSupportedVersion) || update.forceUpdate;
        emit(UpdateAvailable(update: update, isForced: isForced));
      } else {
        emit(UpdateNotAvailable());
      }
    } catch (e) {
      if (isManualCheck) {
        emit(UpdateError('Failed to check for updates: \$e'));
      } else {
        // Fail silently for background checks
        emit(UpdateInitial());
      }
    }
  }

  void startDownload() {
    if (_currentUpdate == null) return;
    
    _downloadManager.onReceiveProgress = (received, total) {
      if (!isClosed) {
        emit(UpdateDownloading(
          progress: total <= 0 ? 0 : received / total,
          receivedBytes: received,
          totalBytes: total,
        ));
      }
    };

    _downloadManager.onDownloadCompleted = () {
      if (!isClosed) {
        emit(UpdateDownloadCompleted());
        _downloadManager.installApk();
      }
    };

    _downloadManager.onDownloadFailed = (error) {
      if (!isClosed) {
        emit(UpdateError(error));
        // Reset state so user can retry
        final isForced = _currentUpdate!.forceUpdate;
        Future.delayed(const Duration(seconds: 2), () {
          if (!isClosed) {
            emit(UpdateAvailable(update: _currentUpdate!, isForced: isForced));
          }
        });
      }
    };

    emit(UpdateDownloading(progress: 0, receivedBytes: 0, totalBytes: 0));
    _downloadManager.startDownload(
      _currentUpdate!.apkUrl, 
      _currentUpdate!.versionName,
      expectedSha256: _currentUpdate!.sha256Hash,
    );
  }

  void pauseDownload() {
    _downloadManager.pauseDownload();
    if (state is UpdateDownloading) {
      final currentState = state as UpdateDownloading;
      emit(UpdateDownloading(
        progress: currentState.progress,
        receivedBytes: currentState.receivedBytes,
        totalBytes: currentState.totalBytes,
        isPaused: true,
      ));
    }
  }

  void resumeDownload() {
    startDownload();
  }

  void cancelDownload() {
    _downloadManager.cancelDownload();
    if (_currentUpdate != null) {
      final isForced = _currentUpdate!.forceUpdate; // Simplified check
      emit(UpdateAvailable(update: _currentUpdate!, isForced: isForced));
    } else {
      emit(UpdateInitial());
    }
  }

  void installApk() {
    _downloadManager.installApk();
  }
}
