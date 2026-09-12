import 'dart:io';

import 'package:vania/env.dart' show env;

import '../config/config.dart';
import '../ioc_container.dart';

/// Decides whether a WebSocket handshake may proceed, based on `Origin`.
///
/// A WebSocket handshake is an ordinary HTTP request, so the browser
/// attaches the user's cookies to it. Nothing in the pipeline read the
/// `Origin` header, which meant any page on the internet could open
/// `new WebSocket('wss://your-app/ws')` and get a socket authenticated as
/// whoever was logged in — Cross-Site WebSocket Hijacking. Unlike a
/// cross-origin `fetch`, there is no preflight and no same-origin policy
/// on the response: the connection just works.
///
/// ## Policy
///
/// * No `Origin` header — allowed. Native clients (mobile apps, CLIs,
///   server-to-server) do not send one, and they are not subject to the
///   attack, which requires a browser to attach ambient credentials. Set
///   `WEBSOCKET_REQUIRE_ORIGIN=true` to reject these too.
/// * Explicit allow-list configured — the origin must be on it. A single
///   `*` entry disables the check.
/// * Nothing configured — same-origin only: the origin's host and port
///   must match the request's `Host`. This is the safe default and is
///   what a normal single-origin app already does.
///
/// Configure with `WEBSOCKET_ALLOWED_ORIGINS` (comma-separated) or
/// `websocket.allowed_origins` in the app config.
class WebSocketOriginPolicy {
  WebSocketOriginPolicy.createDefault();

  factory WebSocketOriginPolicy() =>
      IoCContainer().resolveOrDefault<WebSocketOriginPolicy>(
        WebSocketOriginPolicy.createDefault,
      );

  List<String>? _cachedOrigins;
  bool? _cachedRequireOrigin;

  List<String> _allowedOrigins() {
    final cached = _cachedOrigins;
    if (cached != null) return cached;

    final fromConfig = Config().get('websocket');
    var raw = <String>[];

    if (fromConfig is Map && fromConfig['allowed_origins'] != null) {
      final v = fromConfig['allowed_origins'];
      if (v is List) {
        raw = v.map((e) => e.toString()).toList();
      } else if (v is String) {
        raw = v.split(',');
      }
    } else {
      final fromEnv = env<String>('WEBSOCKET_ALLOWED_ORIGINS', '');
      if (fromEnv.isNotEmpty) raw = fromEnv.split(',');
    }

    return _cachedOrigins = raw
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  bool _requireOrigin() =>
      _cachedRequireOrigin ??= env<bool>('WEBSOCKET_REQUIRE_ORIGIN', false);

  /// Returns true when the handshake in [request] is allowed.
  bool isAllowed(HttpRequest request) {
    final origin = request.headers.value('origin');
    if (origin == null || origin.isEmpty) return !_requireOrigin();

    final allowed = _allowedOrigins();
    if (allowed.contains('*')) return true;

    if (allowed.isNotEmpty) {
      return allowed.contains(origin.trim().toLowerCase());
    }

    return _isSameOrigin(origin, request);
  }

  /// Compares the origin's authority against the request's `Host` header.
  ///
  /// Host carries no scheme, so only host and port are compared. That is
  /// enough to stop a cross-site handshake; scheme downgrades are a
  /// transport concern handled by HSTS.
  bool _isSameOrigin(String origin, HttpRequest request) {
    final host = request.headers.value(HttpHeaders.hostHeader);
    if (host == null || host.isEmpty) return false;

    final Uri originUri;
    try {
      originUri = Uri.parse(origin);
    } catch (_) {
      return false;
    }
    if (originUri.host.isEmpty) return false;

    final originAuthority = originUri.hasPort
        ? '${originUri.host}:${originUri.port}'
        : originUri.host;

    if (originAuthority.toLowerCase() == host.toLowerCase()) return true;

    // `Host` may omit the default port while Origin states it, or the
    // other way round. Compare hosts and normalise the port explicitly.
    final hostUri = Uri.tryParse('scheme://$host');
    if (hostUri == null || hostUri.host.isEmpty) return false;
    if (hostUri.host.toLowerCase() != originUri.host.toLowerCase()) {
      return false;
    }

    final originPort = originUri.hasPort
        ? originUri.port
        : (originUri.scheme == 'https' || originUri.scheme == 'wss' ? 443 : 80);
    final hostPort = hostUri.hasPort ? hostUri.port : originPort;

    return originPort == hostPort;
  }

  /// Rejects the handshake with 403 and closes the connection.
  Future<void> reject(HttpRequest request) async {
    request.response
      ..statusCode = HttpStatus.forbidden
      ..write('WebSocket origin not allowed');
    await request.response.close();
  }
}
