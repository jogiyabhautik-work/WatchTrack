enum SongType {
  opening,
  ending,
  insert,
  soundtrack,
  unknown;

  String get displayName {
    switch (this) {
      case SongType.opening:
        return 'Opening';
      case SongType.ending:
        return 'Ending';
      case SongType.insert:
        return 'Insert Song';
      case SongType.soundtrack:
        return 'Soundtrack';
      case SongType.unknown:
        return 'Unknown';
    }
  }
}
