class AppwriteConstants {
  static const String databaseId = '69f8723d002cda40379e';
  static const String endpoint = 'https://sgp.cloud.appwrite.io/v1';
  static const String projectId = '693d20f1002b63c1bffd';

  // Collection IDs
  static const String trackingCollectionId = 'tracking';
  static const String foldersCollectionId = 'folders';
  static const String userPrefsCollectionId = 'user_prefs';
  static const String favoritesCollectionId = 'favorites';

  // Attribute Keys

  // Common
  static const String attrUserId = 'userId';

  // Tracking
  static const String attrTmdbId = 'tmdbId';
  static const String attrTitle = 'title';
  static const String attrPosterPath = 'posterPath';
  static const String attrBackdropPath = 'backdropPath';
  static const String attrOverview = 'overview';
  static const String attrStatus = 'status';
  static const String attrUserRating = 'userRating';
  static const String attrMediaType = 'mediaType';
  static const String attrProgress = 'progress';
  static const String attrTotalEpisodes = 'totalEpisodes';
  static const String attrWatchedEpisodes = 'watchedEpisodes';
  static const String attrLastSeason = 'lastSeason';
  static const String attrLastEpisode = 'lastEpisode';
  static const String attrIsFavorite = 'isFavorite';
  static const String attrNotes = 'notes';
  static const String attrPriority = 'priority';
  static const String attrTags = 'tags';
  static const String attrRewatchCount = 'rewatchCount';
  static const String attrWatchedAt = 'watchedAt';
  static const String attrAddedAt = 'addedAt';
  static const String attrUpdatedAt = 'updatedAt';

  // Folders
  static const String attrFolderName = 'name';
  static const String attrFolderEmoji = 'emoji';
  static const String attrMovieIds = 'movieIds';
  static const String attrMovieData = 'movieData';
  static const String attrCreatedAt = 'createdAt';

  // User Prefs
  static const String attrFavoriteGenres = 'favoriteGenres';
  static const String attrFavoriteActors = 'favoriteActors';
  static const String attrHistory = 'history'; // List of TMDB IDs
  static const String attrOnboardingDone = 'onboardingDone';
  static const String attrPfpUrl = 'pfpUrl';
}
