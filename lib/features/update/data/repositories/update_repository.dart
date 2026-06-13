import 'package:appwrite/appwrite.dart';
import 'package:watch_track/core/appwrite_client.dart';
import 'package:watch_track/features/update/data/models/update_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UpdateRepository {
  final Databases _databases;
  final String _databaseId = dotenv.get('APPWRITE_DATABASE_ID', fallback: '69f8723d002cda40379e');
  final String _collectionId = 'updates';

  UpdateRepository({Databases? databases}) : _databases = databases ?? Databases(client);

  Future<UpdateModel?> getLatestUpdate() async {
    try {
      final response = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _collectionId,
        queries: [
          Query.equal('is_active', true),
          Query.orderDesc('version_code'),
          Query.limit(1),
        ],
      );

      if (response.documents.isNotEmpty) {
        return UpdateModel.fromMap(response.documents.first.data);
      }
      return null;
    } catch (e) {
      print('Error fetching latest update: $e');
      return null;
    }
  }

  Future<void> createUpdate(UpdateModel update) async {
    try {
      await _databases.createDocument(
        databaseId: _databaseId,
        collectionId: _collectionId,
        documentId: ID.unique(),
        data: update.toMap(),
      );
    } catch (e) {
      print('Error creating update: $e');
      throw e;
    }
  }
}
