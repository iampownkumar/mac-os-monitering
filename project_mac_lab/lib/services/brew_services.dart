import 'dart:convert';
import 'package:http/http.dart' as http;

class BrewService {
  static const String baseUrl = "http://admin-pc.local:8000";

  static Future<Stream<String>> installStream({
    required String macId,
    required String type,
    required String name,
  }) async {
    final uri = Uri.parse(
      "$baseUrl/brew/install/$macId/stream?type=$type&name=$name",
    );

    final request = http.Request("GET", uri);
    final response = await request.send();

    return response.stream.transform(utf8.decoder);
  }

  static Future<void> stopInstall(String macId) async {
    await http.post(Uri.parse("$baseUrl/brew/stop/$macId"));
  }

  static Future<Map<String, bool>> fetchStatus() async {
    final res = await http.get(Uri.parse("$baseUrl/status"));
    final decoded = jsonDecode(res.body);

    final Map<String, dynamic> raw = decoded["machines"];
    return raw.map((k, v) => MapEntry(k, v == true));
  }
}
