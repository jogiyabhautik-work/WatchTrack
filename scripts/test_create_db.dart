import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  HttpOverrides.global = MyHttpOverrides();
  
  final String endpoint = Platform.environment['APPWRITE_ENDPOINT'] ?? 'https://sgp.cloud.appwrite.io/v1';
  final String projectId = Platform.environment['APPWRITE_PROJECT_ID'] ?? '693d20f1002b63c1bffd';
  final String apiKey = Platform.environment['APPWRITE_API_KEY'] ?? 'YOUR_API_KEY';

  Client client = Client()
      .setEndpoint(endpoint)
      .setProject(projectId)
      .setKey(apiKey)
      .setSelfSigned(status: true);

  Databases databases = Databases(client);

  try {
    print('Attempting to create database "watchtrack_main"...');
    final db = await databases.create(databaseId: 'watchtrack_main', name: 'WatchTrack');
    print('Successfully created database: ${db.$id}');
  } catch (e) {
    print('Error creating database: $e');
  }
}
