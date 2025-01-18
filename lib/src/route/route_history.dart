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
    if (req.headers.value('accept').toString().contains('html')) {
      if (_currentRoute.isEmpty) {
        _currentRoute = req.uri.path;
      } else {
        _previousRoute = _currentRoute;
        _currentRoute = req.uri.path;
      }
    }
  }
}
