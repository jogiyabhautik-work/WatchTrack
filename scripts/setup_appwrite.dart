import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:dart_appwrite/enums.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

/// SETUP SCRIPT for Track & Tube Appwrite Database
/// 
/// TO RUN:
/// 1. Replace YOUR_API_KEY below with the one from Appwrite Console.
/// 2. Run: `dart scripts/setup_appwrite.dart`
///
/// REQUIRED SCOPES for API KEY:
/// - databases.read, databases.write
/// - collections.read, collections.write
/// - attributes.read, attributes.write
/// - indexes.read, indexes.write

String getEnv(String key, String defaultValue) {
  return Platform.environment[key] ?? defaultValue;
}

final String endpoint = getEnv('APPWRITE_ENDPOINT', 'https://sgp.cloud.appwrite.io/v1');
final String projectId = getEnv('APPWRITE_PROJECT_ID', '693d20f1002b63c1bffd');
final String apiKey = getEnv('APPWRITE_API_KEY', 'YOUR_API_KEY');

final String dbId = getEnv('APPWRITE_DATABASE_ID', '69f8723d002cda40379e');
const String trackingCollId = 'tracking';
const String foldersCollId = 'folders';
const String userPrefsCollId = 'user_prefs';
const String favoritesCollId = 'favorites';

void main() async {
  HttpOverrides.global = MyHttpOverrides();
  
  if (apiKey == 'YOUR_API_KEY') {
    print('❌ ERROR: Please paste your Appwrite API Key into the script first.');
    return;
  }

  Client client = Client()
      .setEndpoint(endpoint)
      .setProject(projectId)
      .setKey(apiKey)
      .setSelfSigned(status: true);

  Databases databases = Databases(client);

  print('🚀 Starting Appwrite Database Setup...');

  try {
    // 1. Create Database
    try {
      await databases.create(databaseId: dbId, name: 'Track & Tube');
      print('✅ Database "Track & Tube" created.');
    } catch (e) {
      print('ℹ️ Database already exists or error: $e');
    }

    // 2. Create Collections
    await _createTrackingCollection(databases);
    await _createFoldersCollection(databases);
    await _createUserPrefsCollection(databases);
    await _createFavoritesCollection(databases);

    print('\n🎉 SETUP COMPLETE! You can now use these IDs in your app.');
  } catch (e) {
    print('\n❌ FATAL ERROR: $e');
  }
}

// Global helper for attribute creation
Future<void> addAttr(Databases databases, String dbId, String collId, String key, Future Function() call) async {
  try {
    await call();
    print('   ✅ Attribute "$key" created.');
  } catch (e) {
    if (e.toString().contains('already_exists')) {
      print('   ℹ️ Attribute "$key" already exists.');
    } else {
      print('   ❌ Failed to create attribute "$key": $e');
    }
  }
}

Future<void> _createTrackingCollection(Databases databases) async {
  print('\n📦 Setting up Tracking collection...');
  try {
    await databases.createCollection(
      databaseId: dbId,
      collectionId: trackingCollId,
      name: 'Tracking',
      permissions: <String>[
        Permission.read(Role.users()),
        Permission.create(Role.users()),
        Permission.update(Role.users()),
        Permission.delete(Role.users()),
      ],
    );
    
    // Add Attributes
    await databases.createStringAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'userId', size: 36, xrequired: true);
    await databases.createIntegerAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'tmdbId', xrequired: true);
    await databases.createStringAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'title', size: 255, xrequired: true);
    await databases.createStringAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'posterPath', size: 255, xrequired: false);
    await databases.createStringAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'mediaType', size: 10, xrequired: true);
    await databases.createStringAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'status', size: 20, xrequired: true);
    await databases.createFloatAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'userRating', xrequired: false);
    await databases.createIntegerAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'progress', xrequired: false);
    await databases.createDatetimeAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'updatedAt', xrequired: true);
    
    print('✅ Tracking collection attributes added.');
  } catch (e) {
    if (e.toString().contains('collection_already_exists')) {
      print('ℹ️ Tracking collection already exists, adding attributes/indexes...');
    } else {
      print('ℹ️ Tracking collection exists or error: $e');
    }
  }

  // Attempt to add attributes individually in case some are missing
  await addAttr(databases, dbId, trackingCollId, 'userId', () => databases.createStringAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'userId', size: 36, xrequired: true));
  await addAttr(databases, dbId, trackingCollId, 'tmdbId', () => databases.createIntegerAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'tmdbId', xrequired: true));
  await addAttr(databases, dbId, trackingCollId, 'title', () => databases.createStringAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'title', size: 255, xrequired: true));
  await addAttr(databases, dbId, trackingCollId, 'posterPath', () => databases.createStringAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'posterPath', size: 255, xrequired: true));
  await addAttr(databases, dbId, trackingCollId, 'backdropPath', () => databases.createStringAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'backdropPath', size: 255, xrequired: false));
  await addAttr(databases, dbId, trackingCollId, 'overview', () => databases.createStringAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'overview', size: 5000, xrequired: false));
  await addAttr(databases, dbId, trackingCollId, 'mediaType', () => databases.createStringAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'mediaType', size: 10, xrequired: true));
  await addAttr(databases, dbId, trackingCollId, 'status', () => databases.createStringAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'status', size: 20, xrequired: true));
  await addAttr(databases, dbId, trackingCollId, 'userRating', () => databases.createFloatAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'userRating', xrequired: false, min: 0.0, max: 10.0));
  await addAttr(databases, dbId, trackingCollId, 'progress', () => databases.createIntegerAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'progress', xrequired: false, min: 0, max: 100));
  await addAttr(databases, dbId, trackingCollId, 'totalEpisodes', () => databases.createIntegerAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'totalEpisodes', xrequired: false, min: 0));
  await addAttr(databases, dbId, trackingCollId, 'notes', () => databases.createStringAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'notes', size: 2000, xrequired: false));
  await addAttr(databases, dbId, trackingCollId, 'priority', () => databases.createStringAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'priority', size: 20, xrequired: false));
  await addAttr(databases, dbId, trackingCollId, 'tags', () => databases.createStringAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'tags', size: 50, xrequired: false, array: true));
  await addAttr(databases, dbId, trackingCollId, 'rewatchCount', () => databases.createIntegerAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'rewatchCount', xrequired: false, min: 0));
  await addAttr(databases, dbId, trackingCollId, 'watchedAt', () => databases.createDatetimeAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'watchedAt', xrequired: false));
  await addAttr(databases, dbId, trackingCollId, 'addedAt', () => databases.createDatetimeAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'addedAt', xrequired: true));
  await addAttr(databases, dbId, trackingCollId, 'updatedAt', () => databases.createDatetimeAttribute(databaseId: dbId, collectionId: trackingCollId, key: 'updatedAt', xrequired: true));

  // ADD INDEX
  try {
    await databases.createIndex(
      databaseId: dbId,
      collectionId: trackingCollId,
      key: 'userId_index',
      type: IndexType.key,
      attributes: <String>['userId'],
    );
    print('✅ Tracking userId index created.');
  } catch (e) {
    print('ℹ️ Tracking index already exists or error: $e');
  }
}

Future<void> _createFoldersCollection(Databases databases) async {
  print('\n📦 Setting up Folders collection...');
  try {
    await databases.createCollection(
      databaseId: dbId,
      collectionId: foldersCollId,
      name: 'Folders',
      permissions: <String>[
        Permission.read(Role.users()),
        Permission.create(Role.users()),
        Permission.update(Role.users()),
        Permission.delete(Role.users()),
      ],
    );

    await databases.createStringAttribute(databaseId: dbId, collectionId: foldersCollId, key: 'userId', size: 36, xrequired: true);
    await databases.createStringAttribute(databaseId: dbId, collectionId: foldersCollId, key: 'name', size: 50, xrequired: true);
    await databases.createStringAttribute(databaseId: dbId, collectionId: foldersCollId, key: 'emoji', size: 10, xrequired: true);
    await databases.createStringAttribute(databaseId: dbId, collectionId: foldersCollId, key: 'movieIds', size: 20, xrequired: false, array: true);
    await databases.createDatetimeAttribute(databaseId: dbId, collectionId: foldersCollId, key: 'createdAt', xrequired: true);

    print('✅ Folders collection and attributes created.');
  } catch (e) {
    print('ℹ️ Folders collection exists or error: $e');
  }

  // Ensure attributes and index
  await addAttr(databases, dbId, foldersCollId, 'userId', () => databases.createStringAttribute(databaseId: dbId, collectionId: foldersCollId, key: 'userId', size: 36, xrequired: true));
  await addAttr(databases, dbId, foldersCollId, 'name', () => databases.createStringAttribute(databaseId: dbId, collectionId: foldersCollId, key: 'name', size: 128, xrequired: true));
  await addAttr(databases, dbId, foldersCollId, 'emoji', () => databases.createStringAttribute(databaseId: dbId, collectionId: foldersCollId, key: 'emoji', size: 10, xrequired: true));
  await addAttr(databases, dbId, foldersCollId, 'movieIds', () => databases.createStringAttribute(databaseId: dbId, collectionId: foldersCollId, key: 'movieIds', size: 36, xrequired: false, array: true));
  await addAttr(databases, dbId, foldersCollId, 'createdAt', () => databases.createDatetimeAttribute(databaseId: dbId, collectionId: foldersCollId, key: 'createdAt', xrequired: true));

  try {
    await databases.createIndex(databaseId: dbId, collectionId: foldersCollId, key: 'userId_index', type: IndexType.key, attributes: <String>['userId']);
    print('✅ Folders userId index created.');
  } catch(_) {}
}

Future<void> _createUserPrefsCollection(Databases databases) async {
  print('\n📦 Setting up User Preferences collection...');
  try {
    await databases.createCollection(
      databaseId: dbId,
      collectionId: userPrefsCollId,
      name: 'User Preferences',
      permissions: <String>[
        Permission.read(Role.users()),
        Permission.create(Role.users()),
        Permission.update(Role.users()),
        Permission.delete(Role.users()),
      ],
    );

    await databases.createStringAttribute(databaseId: dbId, collectionId: userPrefsCollId, key: 'userId', size: 36, xrequired: true);
    await databases.createStringAttribute(databaseId: dbId, collectionId: userPrefsCollId, key: 'favoriteGenres', size: 50, xrequired: false, array: true);
    await databases.createStringAttribute(databaseId: dbId, collectionId: userPrefsCollId, key: 'favoriteActors', size: 100, xrequired: false, array: true);
    await databases.createStringAttribute(databaseId: dbId, collectionId: userPrefsCollId, key: 'history', size: 20, xrequired: false, array: true);
    await databases.createBooleanAttribute(databaseId: dbId, collectionId: userPrefsCollId, key: 'onboardingDone', xrequired: true, xdefault: false);

    print('✅ User Preferences collection and attributes created.');
  } catch (e) {
    print('ℹ️ User Preferences collection exists or error: $e');
  }

  await addAttr(databases, dbId, userPrefsCollId, 'favoriteGenres', () => databases.createStringAttribute(databaseId: dbId, collectionId: userPrefsCollId, key: 'favoriteGenres', size: 50, xrequired: false, array: true));
  await addAttr(databases, dbId, userPrefsCollId, 'favoriteActors', () => databases.createStringAttribute(databaseId: dbId, collectionId: userPrefsCollId, key: 'favoriteActors', size: 100, xrequired: false, array: true));
  await addAttr(databases, dbId, userPrefsCollId, 'history', () => databases.createStringAttribute(databaseId: dbId, collectionId: userPrefsCollId, key: 'history', size: 36, xrequired: false, array: true));
  await addAttr(databases, dbId, userPrefsCollId, 'pfpUrl', () => databases.createStringAttribute(databaseId: dbId, collectionId: userPrefsCollId, key: 'pfpUrl', size: 255, xrequired: false));
}

Future<void> _createFavoritesCollection(Databases databases) async {
  print('\n📦 Setting up Favorites collection...');
  try {
    await databases.createCollection(
      databaseId: dbId,
      collectionId: favoritesCollId,
      name: 'Favorites',
      permissions: <String>[
        Permission.read(Role.users()),
        Permission.create(Role.users()),
        Permission.update(Role.users()),
        Permission.delete(Role.users()),
      ],
    );

    await databases.createStringAttribute(databaseId: dbId, collectionId: favoritesCollId, key: 'userId', size: 36, xrequired: true);
    await databases.createIntegerAttribute(databaseId: dbId, collectionId: favoritesCollId, key: 'tmdbId', xrequired: true);
    await databases.createDatetimeAttribute(databaseId: dbId, collectionId: favoritesCollId, key: 'addedAt', xrequired: true);

    print('✅ Favorites collection and attributes created.');
  } catch (e) {
    print('ℹ️ Favorites collection exists or error: $e');
  }

  // Ensure attributes and index
  await addAttr(databases, dbId, favoritesCollId, 'userId', () => databases.createStringAttribute(databaseId: dbId, collectionId: favoritesCollId, key: 'userId', size: 36, xrequired: true));
  await addAttr(databases, dbId, favoritesCollId, 'tmdbId', () => databases.createIntegerAttribute(databaseId: dbId, collectionId: favoritesCollId, key: 'tmdbId', xrequired: true));
  await addAttr(databases, dbId, favoritesCollId, 'addedAt', () => databases.createDatetimeAttribute(databaseId: dbId, collectionId: favoritesCollId, key: 'addedAt', xrequired: true));

  try {
    await databases.createIndex(databaseId: dbId, collectionId: favoritesCollId, key: 'userId_index', type: IndexType.key, attributes: <String>['userId']);
    print('✅ Favorites userId index created.');
  } catch(_) {}
}
