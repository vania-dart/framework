import 'dart:convert';

class ElasticsearchResponse {
  ElasticsearchResponse({
    required this.statusCode,
    required this.body,
    required this.rawBody,
    this.headers = const {},
  });

  final int statusCode;
  final dynamic body;
  final String rawBody;
  final Map<String, List<String>> headers;

  bool get isOk => statusCode >= 200 && statusCode < 300;

  Map<String, dynamic> get json {
    if (body is Map<String, dynamic>) return body as Map<String, dynamic>;
    if (rawBody.isEmpty) return {};
    final decoded = jsonDecode(rawBody);
    if (decoded is Map<String, dynamic>) return decoded;
    return {'value': decoded};
  }
}
