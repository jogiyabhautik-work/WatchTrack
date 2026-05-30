enum SongSource {
  animeThemes,
  musicBrainz,
  itunes,
  jikan,
  localCache,
  youtube;

  String get displayName {
    switch (this) {
      case SongSource.animeThemes:
        return 'AnimeThemes';
      case SongSource.musicBrainz:
        return 'MusicBrainz';
      case SongSource.itunes:
        return 'iTunes';
      case SongSource.jikan:
        return 'Jikan / MAL';
      case SongSource.localCache:
        return 'Local Cache';
      case SongSource.youtube:
        return 'YouTube';
    }
  }
}
