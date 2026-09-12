import 'dart:io';

import 'package:vania/websocket.dart'
    show WebSocketUpgradeDispatcher, WebSocketUpgradeHandler;

import '../config/graphql_config.dart';
import '../executor/vania_graphql_executor.dart';
import 'graphql_ws_handler.dart';

/// Installs a `graphql-ws` WebSocket handler on
/// [WebSocketUpgradeDispatcher] without displacing whatever handler
/// (e.g. `vania_websocket`) was already installed.
///
/// The composed handler routes upgrades whose path equals
/// `config.subscriptionsEndpoint` to [GraphQLWsHandler]; every other
/// upgrade is delegated to the previously-installed handler if any, or
/// to the dispatcher default otherwise.
class GraphQLWsDispatcher {
  GraphQLWsDispatcher(this.config, {this.executor});

  final GraphQLConfig config;

  /// Injectable executor for tests. In production the composed handler
  /// builds a fresh [VaniaGraphQLExecutor] per upgrade so it sees the
  /// current schema registry.
  final VaniaGraphQLExecutor? executor;

  /// Install the composed handler. Returns the previous handler that was
  /// installed (may be `null`) so callers can `reset` cleanly if needed.
  WebSocketUpgradeHandler? install() {
    final dispatcher = WebSocketUpgradeDispatcher();
    final previous = dispatcher.currentHandler;

    Future<void> handler(HttpRequest request) async {
      if (_matches(request)) {
        return _handleGraphQL(request);
      }
      if (previous != null) {
        return previous(request);
      }
      // No other WebSocket driver was installed before us. Delegate to the
      // dispatcher with our override cleared so it applies its no-driver
      // behaviour (refuse the upgrade), then restore our handler.
      return _defaultDispatch(request);
    }

    dispatcher.override(handler);
    return previous;
  }

  Future<void> _defaultDispatch(HttpRequest request) async {
    final dispatcher = WebSocketUpgradeDispatcher();
    final saved = dispatcher.currentHandler;
    dispatcher.reset();
    try {
      await dispatcher.dispatch(request);
    } finally {
      if (saved != null) dispatcher.override(saved);
    }
  }

  bool _matches(HttpRequest request) {
    final path = request.uri.path;
    return path == config.subscriptionsEndpoint;
  }

  Future<void> _handleGraphQL(HttpRequest request) async {
    final socket = await WebSocketTransformer.upgrade(
      request,
      protocolSelector: (protocols) {
        if (protocols.contains(GraphQLWsHandler.subprotocol)) {
          return GraphQLWsHandler.subprotocol;
        }
        // Legacy `graphql-ws` (apollo-server-old) also often just accepts
        // whatever the server picks — fall through with the first one.
        return protocols.isNotEmpty ? protocols.first : '';
      },
    );

    final resolvedExecutor = executor ?? VaniaGraphQLExecutor(config: config);
    final handler = GraphQLWsHandler(
      socket,
      executor: resolvedExecutor,
      config: config,
    );
    await handler.run();
  }
}
