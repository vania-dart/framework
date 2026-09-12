import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/elasticsearch_config.dart';
import 'elasticsearch_request.dart';
import 'elasticsearch_response.dart';
import 'elasticsearch_transport.dart';

/// A default [ElasticsearchTransport] backed by `dart:io`'s [HttpClient].
///
/// A fresh [HttpClient] is created for every request so that the two
/// client-wide mutable properties we set — `connectionTimeout` and
/// `badCertificateCallback` — cannot race across concurrent requests.
/// (The `HttpClient` overhead is negligible next to the network round-trip.)
class IoElasticsearchTransport implements ElasticsearchTransport {
  IoElasticsearchTransport({HttpClient Function()? clientFactory})
    : _clientFactory = clientFactory ?? HttpClient.new;

  final HttpClient Function() _clientFactory;

  @override
  Future<ElasticsearchResponse> send(
    Uri host,
    ElasticsearchRequest request,
    ElasticsearchConfig config,
  ) async {
    final client = _clientFactory();
    client.connectionTimeout = config.connectTimeout;
    client.badCertificateCallback = config.allowBadCertificates
        ? (certificate, host, port) => true
        : null;

    try {
      final uri = _uri(host, request);
      final httpRequest = await client
          .openUrl(request.method, uri)
          .timeout(config.connectTimeout);

      _applyHeaders(httpRequest, request, config);
      _writeBody(httpRequest, request);

      final response = await httpRequest.close().timeout(config.requestTimeout);
      final rawBody = await utf8.decoder.bind(response).join();

      final headers = <String, List<String>>{};
      response.headers.forEach((name, values) {
        headers[name] = List<String>.from(values);
      });

      return ElasticsearchResponse(
        statusCode: response.statusCode,
        rawBody: rawBody,
        body: _decode(rawBody),
        headers: headers,
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> close() async {
    // Per-request clients are closed in send(); nothing to do here.
  }

  Uri _uri(Uri host, ElasticsearchRequest request) {
    final normalizedPath = request.path.startsWith('/')
        ? request.path
        : '/${request.path}';
    return host.replace(
      path: _joinPath(host.path, normalizedPath),
      queryParameters: _queryParameters(request.queryParameters),
    );
  }

  String _joinPath(String basePath, String requestPath) {
    final base = basePath.endsWith('/')
        ? basePath.substring(0, basePath.length - 1)
        : basePath;
    return '$base$requestPath'.replaceAll(RegExp(r'//+'), '/');
  }

  Map<String, String>? _queryParameters(Map<String, dynamic> params) {
    if (params.isEmpty) return null;
    final query = <String, String>{};
    for (final entry in params.entries) {
      if (entry.value == null) continue;
      query[entry.key] = entry.value.toString();
    }
    return query;
  }

  void _applyHeaders(
    HttpClientRequest httpRequest,
    ElasticsearchRequest request,
    ElasticsearchConfig config,
  ) {
    httpRequest.headers.set(HttpHeaders.acceptHeader, 'application/json');
    httpRequest.headers.set(
      HttpHeaders.contentTypeHeader,
      request.ndjson ? 'application/x-ndjson' : 'application/json',
    );
    for (final entry in config.headers.entries) {
      httpRequest.headers.set(entry.key, entry.value);
    }
    for (final entry in request.headers.entries) {
      httpRequest.headers.set(entry.key, entry.value);
    }
    final authorization = _authorization(config);
    if (authorization != null) {
      httpRequest.headers.set(HttpHeaders.authorizationHeader, authorization);
    }
  }

  String? _authorization(ElasticsearchConfig config) {
    if (config.apiKey != null) return 'ApiKey ${config.apiKey}';
    if (config.bearerToken != null) return 'Bearer ${config.bearerToken}';
    if (config.username != null && config.password != null) {
      final value = base64Encode(
        utf8.encode('${config.username}:${config.password}'),
      );
      return 'Basic $value';
    }
    return null;
  }

  void _writeBody(HttpClientRequest httpRequest, ElasticsearchRequest request) {
    final body = request.body;
    if (body == null) return;
    if (body is String) {
      httpRequest.write(body);
      return;
    }
    httpRequest.write(jsonEncode(body));
  }

  dynamic _decode(String rawBody) {
    if (rawBody.isEmpty) return null;
    try {
      return jsonDecode(rawBody);
    } catch (_) {
      return rawBody;
    }
  }
}
