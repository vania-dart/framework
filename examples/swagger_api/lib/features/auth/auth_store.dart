import 'dart:convert';
import 'dart:math';

/// Tiny in-memory auth: a demo user, and opaque bearer tokens minted on
/// login. Enough to show a protected route and the Swagger "Authorize"
/// flow without pulling in a database or the full JWT stack.
class AuthStore {
  final Map<String, String> _users = {'demo': 'password'}; // username -> password
  final Map<String, String> _tokens = {}; // token -> username
  final Random _random = Random.secure();

  /// Validates credentials and returns a fresh bearer token, or null.
  String? login(String username, String password) {
    if (_users[username] != password) return null;
    final token = base64Url.encode(
      List<int>.generate(24, (_) => _random.nextInt(256)),
    );
    _tokens[token] = username;
    return token;
  }

  /// The username a token belongs to, or null if the token is unknown.
  String? userFor(String token) => _tokens[token];
}

final AuthStore authStore = AuthStore();
