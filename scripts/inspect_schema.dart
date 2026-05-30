import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  HttpOverrides.global = MyHttpOverrides();
  String endpoint = Platform.environment['APPWRITE_ENDPOINT'] ?? 'https://sgp.cloud.appwrite.io/v1';
  String projectId = Platform.environment['APPWRITE_PROJECT_ID'] ?? '693d20f1002b63c1bffd';
  String apiKey = Platform.environment['APPWRITE_API_KEY'] ?? 'YOUR_API_KEY';
  String dbId = Platform.environment['APPWRITE_DATABASE_ID'] ?? '69f8723d002cda40379e';

  Map<String, String> headers = {
    'x-appwrite-project': projectId,
    'x-appwrite-key': apiKey,
    'Content-Type': 'application/json',
  };

  try {
    print('Checking Tracking collection via RAW API...');
    var response = await http.get(
      Uri.parse('$endpoint/databases/$dbId/collections/tracking'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      print('Collection Name: ${data['name']}');
      print('Attributes (${data['attributes'].length}):');
      for (var attr in data['attributes']) {
        print(' - ${attr['key']} (${attr['type']}, status: ${attr['status']})');
      }
    } else {
      print('Error fetching tracking: ${response.statusCode} - ${response.body}');
    }

    print('\nChecking Folders collection via RAW API...');
    var response2 = await http.get(
      Uri.parse('$endpoint/databases/$dbId/collections/folders'),
      headers: headers,
    );

    if (response2.statusCode == 200) {
      var data = jsonDecode(response2.body);
      print('Collection Name: ${data['name']}');
      print('Attributes:');
      for (var attr in data['attributes']) {
        print(' - ${attr['key']} (${attr['type']}, status: ${attr['status']})');
      }
    } else {
      print('Error fetching folders: ${response2.statusCode} - ${response2.body}');
    }

  } catch (e) {
    print('Fatal Error: $e');
  }
}
