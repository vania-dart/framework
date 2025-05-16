import 'dart:io';

class RouteHistory {
  static final RouteHistory _instance = RouteHistory._internal();
  factory RouteHistory() => _instance;
  RouteHistory._internal();

  String _currentRoute = '';
  String _previousRoute = '';

  String get currentRoute => _currentRoute;
  String get previousRoute => _previousRoute;

  Future<void> updateRouteHistory(HttpRequest req) async {
    // Only track HTML responses
    if (_isHtmlRequest(req)) {
      _updateRoutes(req.uri.path);
    }
  }

  bool _isHtmlRequest(HttpRequest req) {
    final acceptHeader = req.headers.value('accept');
    return acceptHeader != null && acceptHeader.toString().contains('html');
  }

  void _updateRoutes(String path) {
    if (_currentRoute.isEmpty) {
      _currentRoute = path;
    } else {
      _previousRoute = _currentRoute;
      _currentRoute = path;
    }
  }
}
