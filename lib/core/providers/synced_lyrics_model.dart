// lib/core/providers/synced_lyrics_model.dart

class LyricLine {
  final Duration timestamp;
  final String text;

  const LyricLine({required this.timestamp, required this.text});

  @override
  String toString() => '[${timestamp.inSeconds}s] $text';
}

class SyncedLyrics {
  final List<LyricLine> lines;
  final bool isSynced; // true = LRC timestamps, false = plain text

  const SyncedLyrics({required this.lines, required this.isSynced});

  /// Returns the index of the currently active lyric line for a given position
  int currentLineIndex(Duration position) {
    if (lines.isEmpty) return -1;
    if (!isSynced) return -1;

    int active = 0;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].timestamp <= position) {
        active = i;
      } else {
        break;
      }
    }
    return active;
  }

  /// Parses LRC format: [mm:ss.xx] lyric text
  static SyncedLyrics fromLrc(String lrc) {
    final lines = <LyricLine>[];
    final lineRegex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

    for (final rawLine in lrc.split('\n')) {
      final match = lineRegex.firstMatch(rawLine.trim());
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final centiseconds = int.parse(match.group(3)!.padRight(3, '0'));
        final text = match.group(4)!.trim();

        final timestamp = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: centiseconds,
        );

        if (text.isNotEmpty) {
          lines.add(LyricLine(timestamp: timestamp, text: text));
        }
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return SyncedLyrics(lines: lines, isSynced: true);
  }

  /// Wraps plain lyrics (no timestamps) — they still display but won't sync
  static SyncedLyrics fromPlainText(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => LyricLine(timestamp: Duration.zero, text: l))
        .toList();

    return SyncedLyrics(lines: lines, isSynced: false);
  }
}
