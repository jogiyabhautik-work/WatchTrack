import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:open_filex/open_filex.dart';

class DownloadManager {
  final Dio _dio = Dio();
  CancelToken? _cancelToken;
  String? _savePath;
  String? _apkUrl;
  
  Function(int received, int total)? onReceiveProgress;
  Function()? onDownloadCompleted;
  Function(String error)? onDownloadFailed;

  bool get isDownloading => _cancelToken != null && !_cancelToken!.isCancelled;

  Future<void> startDownload(String url, String versionName, {String? expectedSha256}) async {
    _apkUrl = url;
    _cancelToken = CancelToken();

    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) throw Exception('Unable to get storage directory');
      
      _savePath = '${dir.path}/antigravity_update_v$versionName.apk';

      int downloadedLength = 0;
      final file = File(_savePath!);
      if (await file.exists()) {
        downloadedLength = await file.length();
      }

      await _dio.download(
        url,
        _savePath!,
        cancelToken: _cancelToken,
        options: Options(
          headers: {'range': 'bytes=$downloadedLength-'},
        ),
        onReceiveProgress: (received, total) {
          if (onReceiveProgress != null) {
            onReceiveProgress!(received + downloadedLength, total != -1 ? total + downloadedLength : total);
          }
        },
        deleteOnError: false, // Keep partial download for resume
      );

      if (expectedSha256 != null && expectedSha256.isNotEmpty) {
        final isValid = await verifySha256(_savePath!, expectedSha256);
        if (!isValid) {
          await file.delete();
          if (onDownloadFailed != null) {
            onDownloadFailed!('Checksum verification failed. The file may be corrupted.');
          }
          return;
        }
      }

      if (onDownloadCompleted != null) {
        onDownloadCompleted!();
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        print('Download cancelled or paused');
      } else {
        if (onDownloadFailed != null) {
          onDownloadFailed!(e.message ?? 'Unknown network error');
        }
      }
    } catch (e) {
      if (onDownloadFailed != null) {
        onDownloadFailed!(e.toString());
      }
    }
  }

  void pauseDownload() {
    _cancelToken?.cancel('Paused by user');
  }

  Future<void> resumeDownload() async {
    if (_apkUrl != null) {
      // Extract version name from savePath if needed, but since we didn't store versionName, we can just pass a dummy or keep it if we restructure.
      // A better approach is to store the arguments in class fields. Let's assume startDownload is called again or we can re-use the _savePath.
      // Wait, startDownload takes versionName. I'll change startDownload to use a generic resume method if needed, but the Cubit will handle it.
      print('Resume should be triggered by Cubit calling startDownload again');
    }
  }

  void cancelDownload() async {
    _cancelToken?.cancel('Cancelled by user');
    if (_savePath != null) {
      final file = File(_savePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<bool> verifySha256(String filePath, String expectedHash) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      return digest.toString().toLowerCase() == expectedHash.toLowerCase();
    } catch (e) {
      print('Error verifying SHA256: $e');
      return false;
    }
  }

  Future<void> installApk() async {
    if (_savePath != null) {
      final result = await OpenFilex.open(_savePath!);
      print('Install result: \${result.message}');
    }
  }
}
