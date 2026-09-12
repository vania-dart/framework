import 'dart:convert';
import 'dart:io';

class Service {
  final httpClient = HttpClient();
  Future<String> fetchVaniaVersion() async {
    try {
      final uri = Uri.parse('https://pub.dev/api/packages/vania');
      final request = await httpClient.getUrl(uri);
      final response = await request.close();

      if (response.statusCode == HttpStatus.ok) {
        final responseBody = await response.transform(utf8.decoder).join();
        final jsonData = json.decode(responseBody);
        return jsonData['latest']['version'];
      } else {
        return "";
      }
    } catch (e) {
      return "";
    } finally {
      httpClient.close();
    }
  }
}
