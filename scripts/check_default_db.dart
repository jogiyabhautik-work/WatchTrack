// ignore_for_file: avoid_print, deprecated_member_use
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
    print('Checking for database "default"...');
    final db = await databases.get(databaseId: 'default');
    print('Found "default" database: ${db.name}');
  } catch (e) {
    print('Error getting "default" database: $e');
  }
}
