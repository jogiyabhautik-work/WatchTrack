import 'package:dart_appwrite/dart_appwrite.dart';
import 'dart:io';

void main() async {
  final client = Client()
    ..setEndpoint('https://sgp.cloud.appwrite.io/v1')
    ..setProject('693d20f1002b63c1bffd')
    ..setKey('standard_1fb3ea22b9af7e82f7d21e68cb1f42235c86cdc726a13cb16f3160d5a7112db960f76affc55e62a4f9b40fafa1dfc4d9f33daee7c91ae4470f32136e94185d244b1ca7bd6ff1d657f214d28cb8f0641e58541385956145fc0d3e160e469776248c6b20a828eaa27763d2b4d980a50f7d4118be33cd5d09887381adafe2d9eab5');

  final databases = Databases(client);
  final databaseId = '69f8723d002cda40379e';

  try {
    print('Creating updates collection...');
    final collection = await databases.createCollection(
      databaseId: databaseId,
      collectionId: 'updates',
      name: 'Updates',
      permissions: [
        Permission.read(Role.any()),
        Permission.write(Role.users()), // Admins only typically, but we leave it to users for now
      ],
      documentSecurity: false,
    );

    print('Collection created. Adding attributes...');
    
    // version_name (String)
    await databases.createStringAttribute(databaseId: databaseId, collectionId: 'updates', key: 'version_name', size: 50, xrequired: true);
    // version_code (Integer)
    await databases.createIntegerAttribute(databaseId: databaseId, collectionId: 'updates', key: 'version_code', xrequired: true);
    // release_notes (String)
    await databases.createStringAttribute(databaseId: databaseId, collectionId: 'updates', key: 'release_notes', size: 5000, xrequired: false);
    // apk_url (String)
    await databases.createStringAttribute(databaseId: databaseId, collectionId: 'updates', key: 'apk_url', size: 1000, xrequired: true);
    // apk_size (String)
    await databases.createStringAttribute(databaseId: databaseId, collectionId: 'updates', key: 'apk_size', size: 20, xrequired: false);
    // force_update (Boolean)
    await databases.createBooleanAttribute(databaseId: databaseId, collectionId: 'updates', key: 'force_update', xrequired: true, xdefault: false);
    // release_date (Datetime)
    await databases.createDatetimeAttribute(databaseId: databaseId, collectionId: 'updates', key: 'release_date', xrequired: true);
    // min_supported_version (Integer)
    await databases.createIntegerAttribute(databaseId: databaseId, collectionId: 'updates', key: 'min_supported_version', xrequired: true);
    // changelog (Array) -> String array
    await databases.createStringAttribute(databaseId: databaseId, collectionId: 'updates', key: 'changelog', size: 1000, xrequired: false, array: true);
    // is_active (Boolean)
    await databases.createBooleanAttribute(databaseId: databaseId, collectionId: 'updates', key: 'is_active', xrequired: true, xdefault: false);
    // sha256_hash (String)
    await databases.createStringAttribute(databaseId: databaseId, collectionId: 'updates', key: 'sha256_hash', size: 100, xrequired: false);

    print('Attributes added successfully. Waiting for Appwrite to process attributes...');
    await Future.delayed(Duration(seconds: 5));
    print('Done!');
  } catch (e) {
    print('Error: $e');
  }
}
