import 'dart:io';

import 'websocket_origin_policy.dart';

typedef WebSocketUpgradeHandler = Future<void> Function(HttpRequest request);

/// Singleton dispatcher that owns which handler processes an incoming
/// WebSocket upgrade on the app's HTTP server.
///
/// Core ships no WebSocket implementation of its own. An extension package
/// such as `vania_websocket` (or GraphQL subscriptions) registers a handler
/// by calling [override] from its [ServiceProvider.boot]; every upgrade on
/// the app's single HTTP port is then routed through that handler. With no
/// handler installed, upgrades are refused — a plain Vania app has no
/// WebSocket surface until a driver package is added.
///
/// Because the app boots one [HttpServer] on `APP_HOST`/`APP_PORT`, and the
/// request pipeline delegates every upgrade to this dispatcher, WebSocket
/// traffic always shares the HTTP port — no second server, no second port.
class WebSocketUpgradeDispatcher {
  static final WebSocketUpgradeDispatcher _singleton =
      WebSocketUpgradeDispatcher._internal();
  factory WebSocketUpgradeDispatcher() => _singleton;
  WebSocketUpgradeDispatcher._internal();

  WebSocketUpgradeHandler? _handler;

  /// The handler currently installed via [override], or `null` when no
  /// driver has registered one. Extension packages that need to compose
  /// with an existing override (e.g. GraphQL subscriptions layered on top
  /// of `vania_websocket`) can capture this before calling [override] and
  /// delegate to it as a fallback.
  WebSocketUpgradeHandler? get currentHandler => _handler;

  /// Register the handler that will process every WebSocket upgrade.
  void override(WebSocketUpgradeHandler handler) {
    _handler = handler;
  }

  /// Clear the installed handler. After this, upgrades are refused until a
  /// handler is registered again.
  void reset() {
    _handler = null;
  }

  /// Dispatch an upgrade request to the installed handler, refusing it when
  /// no driver package has registered one.
  ///
  /// The origin check runs here rather than in each handler because this
  /// is the single point every upgrade passes through — `vania_websocket`
  /// and GraphQL subscriptions all arrive via [dispatch], so one check
  /// covers them and no future handler can forget it.
  Future<void> dispatch(HttpRequest request) async {
    final originPolicy = WebSocketOriginPolicy();
    if (!originPolicy.isAllowed(request)) {
      await originPolicy.reject(request);
      return;
    }

    final handler = _handler;
    if (handler != null) {
      await handler(request);
      return;
    }

    // No WebSocket driver installed: refuse the upgrade.
    request.response.statusCode = HttpStatus.notImplemented;
    await request.response.close();
  }
}
