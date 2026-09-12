import 'dart:async';
import 'package:vania/src/ioc_container.dart';
import 'dart:io';

import 'package:vania/src/http/request/request_scope.dart';

/// Tracks the current + previous route for `Response.back()`.
class RouteHistory {
  RouteHistory.createDefault();

  factory RouteHistory() =>
      IoCContainer().resolveOrDefault<RouteHistory>(RouteHistory.createDefault);

  /// Fallback used when someone touches [currentRoute] / [previousRoute]
  /// outside of a request (background jobs, tests). Not concurrency-safe
  /// but nothing outside the request pipeline should be racing on it.
  final _RouteHistoryState _fallback = _RouteHistoryState();

  String get currentRoute =>
      currentRequestScope?.currentRoute ?? _fallback.currentRoute;

  String get previousRoute =>
      currentRequestScope?.previousRoute ?? _fallback.previousRoute;

  static Future<T> runInRequestZone<T>(
    Future<T> Function() body, {
    String previousRoute = '',
    String currentRoute = '',
  }) {
    final state = _RouteHistoryState()
      ..previousRoute = previousRoute
      ..currentRoute = currentRoute;
    return runZoned<Future<T>>(
      body,
      zoneValues: {#vania.route_history.legacy: state},
    );
  }

  Future<void> updateRouteHistory(HttpRequest req) async {
    if (!_isHtmlRequest(req)) return;
    _update(req.uri.path);
  }

  bool _isHtmlRequest(HttpRequest req) {
    final accept = req.headers.value('accept');
    return accept != null && accept.contains('html');
  }

  void _update(String path) {
    final scope = currentRequestScope;
    if (scope != null) {
      if (scope.currentRoute.isEmpty) {
        scope.currentRoute = path;
      } else {
        scope.previousRoute = scope.currentRoute;
        scope.currentRoute = path;
      }
      return;
    }
    // Legacy zone path.
    final legacy = Zone.current[#vania.route_history.legacy];
    if (legacy is _RouteHistoryState) {
      if (legacy.currentRoute.isEmpty) {
        legacy.currentRoute = path;
      } else {
        legacy.previousRoute = legacy.currentRoute;
        legacy.currentRoute = path;
      }
      return;
    }
    // No scope, no legacy zone — write to the fallback.
    if (_fallback.currentRoute.isEmpty) {
      _fallback.currentRoute = path;
    } else {
      _fallback.previousRoute = _fallback.currentRoute;
      _fallback.currentRoute = path;
    }
  }
}

class _RouteHistoryState {
  String currentRoute = '';
  String previousRoute = '';
}
