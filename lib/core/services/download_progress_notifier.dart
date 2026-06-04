import 'package:flutter/foundation.dart';

class DownloadProgressNotifier extends ChangeNotifier {
  static final DownloadProgressNotifier _instance = DownloadProgressNotifier._internal();
  factory DownloadProgressNotifier() => _instance;
  DownloadProgressNotifier._internal();

  final Map<String, double> _progress = {};

  double? getProgress(String key) => _progress[key];

  void updateProgress(String key, double progress) {
    _progress[key] = progress;
    notifyListeners();
  }

  void removeProgress(String key) {
    if (_progress.containsKey(key)) {
      _progress.remove(key);
      notifyListeners();
    }
  }
}
