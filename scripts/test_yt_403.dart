import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;

void main() async {
  var yt = YoutubeExplode();
  print('Fetching manifest...');
  var manifest = await yt.videos.streamsClient.getManifest('dQw4w9WgXcQ'); // Rickroll
  var url = manifest.audioOnly.first.url;
  
  print('Fetching URL without extra headers...');
  var resp1 = await http.get(url, headers: {'Range': 'bytes=0-100'});
  print('Response 1: ${resp1.statusCode}');

  print('Fetching URL WITH extra headers...');
  var resp2 = await http.get(url, headers: {
    'Range': 'bytes=0-100',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://www.youtube.com/',
    'Origin': 'https://www.youtube.com'
  });
  print('Response 2: ${resp2.statusCode}');

  yt.close();
}
