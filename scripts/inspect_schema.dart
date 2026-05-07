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
  String endpoint = 'https://sgp.cloud.appwrite.io/v1';
  String projectId = '693d20f1002b63c1bffd';
  String apiKey = 'standard_1fb3ea22b9af7e82f7d21e68cb1f42235c86cdc726a13cb16f3160d5a7112db960f76affc55e62a4f9b40fafa1dfc4d9f33daee7c91ae4470f32136e94185d244b1ca7bd6ff1d657f214d28cb8f0641e58541385956145fc0d3e160e469776248c6b20a828eaa27763d2b4d980a50f7d4118be33cd5d09887381adafe2d9eab5';
  String dbId = '69f8723d002cda40379e';

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
