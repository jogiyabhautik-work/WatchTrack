import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:dart_appwrite/models.dart' as models;
import 'package:watch_track/core/appwrite_constants.dart';

class AppwriteSchemaManager {
  final Client client;
  late final Databases databases;

  AppwriteSchemaManager({
    required String endpoint,
    required String projectId,
    required String apiKey,
  }) : client = Client()
            .setEndpoint(endpoint)
            .setProject(projectId)
            .setKey(apiKey) {
    databases = Databases(client);
  }

  static const String _apiKey = String.fromEnvironment('APPWRITE_API_KEY');

  static Future<void> setupIfAvailable() async {
    if (_apiKey.isEmpty) {
      print('ℹ️ Appwrite API key not found in environment. Skipping automatic schema setup.');
      return;
    }

    final manager = AppwriteSchemaManager(
      endpoint: AppwriteConstants.endpoint, // Assuming it exists in Constants
      projectId: AppwriteConstants.projectId,
      apiKey: _apiKey,
    );
    await manager.setupSchema();
  }

  Future<void> setupSchema() async {
    print('🚀 Starting Appwrite Schema Setup...');

    try {
      // 1. Setup Tracking Collection Attributes
      await _ensureTrackingAttributes();

      // 2. Setup Folders Collection Attributes
      await _ensureFoldersAttributes();

      // 3. Setup User Prefs Collection Attributes
      await _ensureUserPrefsAttributes();

      print('✅ Schema setup completed successfully!');
    } catch (e) {
      print('❌ Schema setup failed: $e');
    }
  }

  Future<void> _ensureTrackingAttributes() async {
    print('📝 Checking Tracking collection attributes...');
    final collectionId = AppwriteConstants.trackingCollectionId;
    final databaseId = AppwriteConstants.databaseId;

    final attributes = [
      _Attr(AppwriteConstants.attrUserId, 'string', required: true),
      _Attr(AppwriteConstants.attrTmdbId, 'integer', required: true),
      _Attr(AppwriteConstants.attrTitle, 'string', required: true),
      _Attr(AppwriteConstants.attrPosterPath, 'string', required: false),
      _Attr(AppwriteConstants.attrBackdropPath, 'string', required: false),
      _Attr(AppwriteConstants.attrOverview, 'string', size: 5000, required: false),
      _Attr(AppwriteConstants.attrStatus, 'string', defaultValue: 'watchlist'),
      _Attr(AppwriteConstants.attrMediaType, 'string', defaultValue: 'movie'),
      _Attr(AppwriteConstants.attrProgress, 'integer', defaultValue: 0),
      _Attr(AppwriteConstants.attrTotalEpisodes, 'integer', defaultValue: 0),
      _Attr(AppwriteConstants.attrWatchedEpisodes, 'string', isArray: true),
      _Attr(AppwriteConstants.attrLastSeason, 'integer', defaultValue: 0),
      _Attr(AppwriteConstants.attrLastEpisode, 'integer', defaultValue: 0),
      _Attr(AppwriteConstants.attrUserRating, 'double', required: false),
      _Attr(AppwriteConstants.attrPriority, 'string', defaultValue: 'Medium'),
      _Attr(AppwriteConstants.attrIsFavorite, 'boolean', defaultValue: false),
      _Attr(AppwriteConstants.attrNotes, 'string', size: 5000, required: false),
      _Attr(AppwriteConstants.attrTags, 'string', isArray: true),
      _Attr(AppwriteConstants.attrRewatchCount, 'integer', defaultValue: 0),
      _Attr(AppwriteConstants.attrWatchedAt, 'string', required: false),
      _Attr(AppwriteConstants.attrAddedAt, 'string', required: false),
      _Attr(AppwriteConstants.attrUpdatedAt, 'string', required: false),
    ];

    await _createMissingAttributes(databaseId, collectionId, attributes);
  }

  Future<void> _ensureFoldersAttributes() async {
    print('📝 Checking Folders collection attributes...');
    final collectionId = AppwriteConstants.foldersCollectionId;
    final databaseId = AppwriteConstants.databaseId;

    final attributes = [
      _Attr(AppwriteConstants.attrUserId, 'string', required: true),
      _Attr(AppwriteConstants.attrFolderName, 'string', required: true),
      _Attr(AppwriteConstants.attrFolderEmoji, 'string', defaultValue: '📁'),
      _Attr(AppwriteConstants.attrMovieIds, 'string', isArray: true),
      _Attr(AppwriteConstants.attrMovieData, 'string', isArray: true, size: 10000),
      _Attr(AppwriteConstants.attrCreatedAt, 'string', required: false),
    ];

    await _createMissingAttributes(databaseId, collectionId, attributes);
  }

  Future<void> _ensureUserPrefsAttributes() async {
    print('📝 Checking User Prefs collection attributes...');
    final collectionId = AppwriteConstants.userPrefsCollectionId;
    final databaseId = AppwriteConstants.databaseId;

    final attributes = [
      _Attr(AppwriteConstants.attrUserId, 'string', required: true),
      _Attr(AppwriteConstants.attrFavoriteGenres, 'string', isArray: true),
      _Attr(AppwriteConstants.attrFavoriteActors, 'string', isArray: true),
      _Attr(AppwriteConstants.attrHistory, 'string', isArray: true),
      _Attr(AppwriteConstants.attrOnboardingDone, 'boolean', defaultValue: false),
      _Attr(AppwriteConstants.attrPfpUrl, 'string', required: false),
    ];

    await _createMissingAttributes(databaseId, collectionId, attributes);
  }

  Future<void> _createMissingAttributes(
      String dbId, String collId, List<_Attr> targets) async {
    final existing = await databases.listAttributes(
      databaseId: dbId,
      collectionId: collId,
    );

    final existingKeys = existing.attributes.map((a) {
      if (a is Map) return a['key'] as String;
      // Handle Attribute objects from dart_appwrite SDK
      try {
        final Map<String, dynamic> data = (a as dynamic).toMap();
        return data['key'] as String;
      } catch (_) {
        try {
          return (a as dynamic).key as String;
        } catch (__) {
          return '';
        }
      }
    }).toSet();

    for (var target in targets) {
      if (existingKeys.contains(target.key)) {
        print('  - Attribute "${target.key}" already exists. Skipping.');
        continue;
      }

      print('  + Creating attribute "${target.key}"...');
      try {
        switch (target.type) {
          case 'string':
            await databases.createStringAttribute(
              databaseId: dbId,
              collectionId: collId,
              key: target.key,
              size: target.size ?? 255,
              xrequired: target.required,
              array: target.isArray,
              xdefault: target.defaultValue as String?,
            );
            break;
          case 'boolean':
            await databases.createBooleanAttribute(
              databaseId: dbId,
              collectionId: collId,
              key: target.key,
              xrequired: target.required,
              xdefault: target.defaultValue as bool?,
            );
            break;
          case 'integer':
            await databases.createIntegerAttribute(
              databaseId: dbId,
              collectionId: collId,
              key: target.key,
              xrequired: target.required,
              xdefault: target.defaultValue as int?,
            );
            break;
          case 'double':
            await databases.createFloatAttribute(
              databaseId: dbId,
              collectionId: collId,
              key: target.key,
              xrequired: target.required,
              xdefault: target.defaultValue as double?,
            );
            break;
        }
        // Appwrite needs time to process attribute creation
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        print('    ⚠️ Error creating "${target.key}": $e');
      }
    }
  }
}

class _Attr {
  final String key;
  final String type;
  final bool isArray;
  final bool required;
  final dynamic defaultValue;
  final int? size;

  _Attr(this.key, this.type,
      {this.isArray = false,
      this.required = false,
      this.defaultValue,
      this.size});
}
