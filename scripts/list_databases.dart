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
  
  final String endpoint = 'https://sgp.cloud.appwrite.io/v1';
  final String projectId = '693d20f1002b63c1bffd';
  final String apiKey = 'standard_1fb3ea22b9af7e82f7d21e68cb1f42235c86cdc726a13cb16f3160d5a7112db960f76affc55e62a4f9b40fafa1dfc4d9f33daee7c91ae4470f32136e94185d244b1ca7bd6ff1d657f214d28cb8f0641e58541385956145fc0d3e160e469776248c6b20a828eaa27763d2b4d980a50f7d4118be33cd5d09887381adafe2d9eab5';

  Client client = Client()
      .setEndpoint(endpoint)
      .setProject(projectId)
      .setKey(apiKey)
      .setSelfSigned(status: true);

  Databases databases = Databases(client);

  try {
    final response = await databases.list();
    print('Found ${response.total} databases:');
    for (var db in response.databases) {
      print('- ID: ${db.$id}, Name: ${db.name}');
    }
  } catch (e) {
    print('Error listing databases: $e');
  }
}
