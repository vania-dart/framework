import 'dart:convert';

import 'package:vania/http/request.dart' show Request;
import 'package:vania/http/response.dart' show Response;

import '../config/swagger_config.dart';
import '../generator/swagger_generator.dart';
import '../generator/yaml_emitter.dart';
import 'swagger_page_renderer.dart';

/// HTTP handlers for the Swagger doc routes. Registered by
/// [SwaggerServiceProvider] on the app's `Router`.
class SwaggerController {
  SwaggerController(this.config);

  final SwaggerConfig config;

  /// Renders the Swagger UI HTML.
  Future<Response> renderUi(Request request) async {
    final base = config.normalizedBasePath();
    final html = SwaggerPageRenderer.render(
      specUrl: '$base/swagger.json',
      title: config.title,
    );
    return Response.html(html, headers: _headers('text/html; charset=utf-8'));
  }

  /// Serves the OpenAPI 3.1 spec as JSON.
  Future<Response> serveJson(Request request) async {
    final spec = _spec(request);
    return Response.jsonWithHeader(spec, headers: _headers('application/json'));
  }

  /// Serves the OpenAPI 3.1 spec as YAML.
  Future<Response> serveYaml(Request request) async {
    final spec = _spec(request);
    final yaml = encodeYaml(spec);
    // `Response.html` uses the raw body writer we need; there's no
    // dedicated YAML factory in core, so ship it under `text/yaml` via
    // `Response.html` (which honours the `headers` map for content-type).
    return Response.html(yaml, headers: _headers('application/yaml'));
  }

  Map<String, dynamic> _spec(Request request) {
    return SwaggerGenerator().generate(
      serverUrl: config.serverUrl ?? _inferServer(request),
    );
  }

  String? _inferServer(Request request) {
    try {
      final host = request.host;
      final scheme = request.uri.scheme.isNotEmpty
          ? request.uri.scheme
          : 'http';
      if (host.isEmpty) return null;
      return '$scheme://$host';
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _headers(String contentType) {
    return {
      'content-type': contentType,
      if (config.corsEnabled) 'access-control-allow-origin': '*',
      ...config.responseHeaders,
    };
  }
}

/// A tiny helper that pretty-prints JSON. The controller uses this only
/// for tests that assert on the raw body.
String prettyJson(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);
