import 'dart:async';
import 'package:vania/vania.dart' show IoCContainer;

import 'package:meta/meta.dart';
import 'package:vania/http/request.dart' show currentRequestScope;
import 'package:vania/vania.dart' show PersonalAccessTokenStore;

import '../contracts/user_provider.dart';
import '../crypto/hash.dart';
import '../crypto/token_hasher.dart';
import '../jwt/jwt_service.dart';
import 'gate.dart';

class Auth {
  /// Builds an isolated instance.
  ///
  /// `Auth()` returns the shared one; use this when a test or a piece
  /// of code needs its own.
  Auth.createDefault();

  factory Auth() => IoCContainer().resolveOrDefault<Auth>(Auth.createDefault);

  static const Object _stateZoneKey = #vaniaAuthState;

  final AuthState _rootState = AuthState();
  final Map<String, AuthGuardConfig> _guards = {'default': AuthGuardConfig()};

  /// Resolves the auth state for the caller, in priority order:
  ///
  /// 1. an explicit [runWithContext] / [runWithAsyncContext] zone, for
  ///    tests and background jobs that want an isolated auth context;
  /// 2. the per-request [RequestScope] that core's `RequestHandler` binds
  ///    around every request — the path real HTTP traffic takes;
  /// 3. `_rootState`, for calls made outside any request (boot, CLI,
  ///    one-off scripts).
  ///
  /// Binding to the request scope is what lets `Auth().id` stay callable
  /// from anywhere — models, services, helpers — without threading a
  /// `Request` through every signature, while still resolving to the
  /// current request's user under concurrent load.
  AuthState get _state {
    final zoneState = Zone.current[_stateZoneKey];
    if (zoneState is AuthState) return zoneState;

    final scope = currentRequestScope;
    if (scope != null) {
      final existing = scope.attributes[_stateZoneKey];
      if (existing is AuthState) return existing;
      final fresh = AuthState();
      scope.attributes[_stateZoneKey] = fresh;
      return fresh;
    }

    return _rootState;
  }

  bool get loggedIn => _state.hasUser(_state.currentGuard);
  Map<String, dynamic> get currentUser => _state.user(_state.currentGuard);
  dynamic get id => currentUser['id'] ?? currentUser['_id'];

  dynamic get(String field) => currentUser[field];

  @visibleForTesting
  void reset() {
    _guards
      ..clear()
      ..['default'] = AuthGuardConfig();
    _rootState.clearAll();
    _rootState.currentGuard = 'default';
  }

  void setTokenStore(
    PersonalAccessTokenStore store, {
    String guard = 'default',
  }) {
    configureGuard(guard, tokenStore: store);
  }

  void setUserProvider(UserProvider provider, {String guard = 'default'}) {
    configureGuard(guard, userProvider: provider);
  }

  void configureGuard(
    String guard, {
    PersonalAccessTokenStore? tokenStore,
    UserProvider? userProvider,
  }) {
    final current = _guards[guard] ?? AuthGuardConfig();
    _guards[guard] = current.copyWith(
      tokenStore: tokenStore,
      userProvider: userProvider,
    );
  }

  T runWithContext<T>(T Function() action, {String guard = 'default'}) {
    return runZoned(
      action,
      zoneValues: {_stateZoneKey: AuthState(currentGuard: guard)},
    );
  }

  Future<T> runWithAsyncContext<T>(
    Future<T> Function() action, {
    String guard = 'default',
  }) {
    return runZoned(
      action,
      zoneValues: {_stateZoneKey: AuthState(currentGuard: guard)},
    );
  }

  AuthGuardConfig _guardConfig(String guard) {
    return _guards[guard] ?? _guards['default'] ?? AuthGuardConfig();
  }

  PersonalAccessTokenStore _requireTokenStore(String guard) {
    final store = _guardConfig(guard).tokenStore;
    if (store == null) {
      throw StateError(
        'PersonalAccessTokenStore not configured. '
        'Call Auth().setTokenStore(), Auth().configureGuard(), '
        'or register an ORM auth provider.',
      );
    }
    return store;
  }

  Auth guard(String guard) {
    _state.currentGuard = guard;
    return this;
  }

  String get currentGuard => _state.currentGuard;

  Auth login(Map<String, dynamic> user) {
    _state.login(_state.currentGuard, user);
    return this;
  }

  void logout() {
    _state.logout(_state.currentGuard);
  }

  void clearAll() {
    _state.clearAll();
  }

  Future<Map<String, dynamic>> createToken({
    Duration? expiresIn,
    bool withRefreshToken = false,
    bool customToken = false,
  }) async {
    final guard = _state.currentGuard;
    final user = _state.userOrNull(guard);
    if (user == null) {
      throw StateError('No user logged in. Call Auth().login() first.');
    }

    final token = JwtService().createToken(
      payload: user,
      guard: guard,
      expiresIn: expiresIn,
      withRefreshToken: withRefreshToken,
    );

    if (!customToken) {
      final store = _requireTokenStore(guard);
      final tokenableId = user['id'] ?? user['_id'];

      await store.create(
        name: guard,
        tokenableId: tokenableId,
        tokenHash: TokenHasher.hash(token['access_token']),
        expiresIn: expiresIn,
      );

      // The refresh token is recorded too: a stored hash is what makes
      // it revocable, and what lets `revokeAll` reach it.
      final refresh = token['refresh_token'];
      if (refresh is String) {
        await store.create(
          name: _refreshTokenName(guard),
          tokenableId: tokenableId,
          tokenHash: TokenHasher.hash(refresh),
          expiresIn: JwtService().refreshTokenTtl,
        );
      }
    }

    return token;
  }

  /// Name refresh tokens are stored under, so they can be told apart from
  /// access tokens in the store.
  static String _refreshTokenName(String guard) => '$guard:refresh';

  Future<Map<String, dynamic>> createTokenByRefreshToken(
    String refreshToken, {
    Duration? expiresIn,
    bool customToken = false,
  }) async {
    final guard = _state.currentGuard;
    final cleanToken = refreshToken.replaceFirst('Bearer ', '');
    final newToken = JwtService().refreshToken(
      cleanToken,
      guard,
      expiresIn: expiresIn,
    );

    if (!customToken) {
      final payload = JwtService().verify(cleanToken, guard, 'refresh_token');

      final userId = payload['id'] ?? payload['_id'];

      final store = _requireTokenStore(guard);
      final userProvider = _guardConfig(guard).userProvider;
      final presentedHash = TokenHasher.hash(cleanToken);

      // An already-revoked refresh token means it is being replayed.
      // The whole family is invalidated: once one token of the pair is
      // known to have leaked, the current one is suspect too.
      if (await store.isRevoked(presentedHash)) {
        await store.revokeAll(userId);
        throw JwtAuthException('Refresh token reuse detected');
      }

      // Tokens issued before refresh tokens were recorded have no row in
      // the store. They are accepted once, and the rotation below writes
      // a row for their replacement.
      final known = await store.exists(presentedHash);

      if (userProvider != null) {
        final user = await userProvider.findById(userId);
        if (user == null) {
          throw JwtAuthException('User not found');
        }
        _state.login(guard, user);
      }

      // Rotate: the presented refresh token is single-use.
      if (known) {
        await store.revoke(presentedHash);
      }

      await store.create(
        name: guard,
        tokenableId: userId,
        tokenHash: TokenHasher.hash(newToken['access_token']),
        expiresIn: expiresIn,
      );

      final rotated = newToken['refresh_token'];
      if (rotated is String) {
        await store.create(
          name: _refreshTokenName(guard),
          tokenableId: userId,
          tokenHash: TokenHasher.hash(rotated),
          expiresIn: JwtService().refreshTokenTtl,
        );
      }
    }

    return newToken;
  }

  Future<bool> check(
    String token, {
    Map<String, dynamic>? user,
    bool isCustomToken = false,
  }) async {
    final guard = _state.currentGuard;
    final cleanToken = token.replaceFirst('Bearer ', '');
    final payload = JwtService().verify(cleanToken, guard, 'access_token');

    if (isCustomToken) {
      _state.login(guard, payload);
      return true;
    }

    final tokenHash = TokenHasher.hash(cleanToken);
    final store = _requireTokenStore(guard);

    if (await store.isRevoked(tokenHash)) {
      throw JwtAuthException('Token has been revoked');
    }

    final exists = await store.exists(tokenHash);
    if (!exists) {
      throw JwtAuthException('Token not found');
    }

    await store.markUsed(tokenHash);

    if (user == null) {
      final userProvider = _guardConfig(guard).userProvider;
      if (userProvider != null) {
        final userId = payload['id'] ?? payload['_id'];
        user = await userProvider.findById(userId);
      }
    }

    if (user != null) {
      _state.login(guard, user);
      return true;
    }

    throw JwtAuthException('User not found');
  }

  Future<bool> revokeToken(String token) async {
    final guard = _state.currentGuard;
    final cleanToken = token.replaceFirst('Bearer ', '');
    final tokenHash = TokenHasher.hash(cleanToken);
    await _requireTokenStore(guard).revoke(tokenHash);
    return true;
  }

  Future<bool> revokeAllTokens(dynamic userId) async {
    await _requireTokenStore(_state.currentGuard).revokeAll(userId);
    return true;
  }

  Future<bool> revokeAllTokensByName(String name) async {
    await _requireTokenStore(_state.currentGuard).revokeAllByName(name);
    return true;
  }

  bool authorize(String ability) {
    return Gate().allows(ability);
  }

  bool denies(String ability) {
    return Gate().denies(ability);
  }

  PasswordHasher get hash => PasswordHasher();
}

class AuthGuardConfig {
  final PersonalAccessTokenStore? tokenStore;
  final UserProvider? userProvider;

  const AuthGuardConfig({this.tokenStore, this.userProvider});

  AuthGuardConfig copyWith({
    PersonalAccessTokenStore? tokenStore,
    UserProvider? userProvider,
  }) {
    return AuthGuardConfig(
      tokenStore: tokenStore ?? this.tokenStore,
      userProvider: userProvider ?? this.userProvider,
    );
  }
}

class AuthState {
  String currentGuard;
  final Map<String, Map<String, dynamic>> _users = {};

  AuthState({this.currentGuard = 'default'});

  bool hasUser(String guard) => _users.containsKey(guard);

  Map<String, dynamic> user(String guard) => _users[guard] ?? {};

  Map<String, dynamic>? userOrNull(String guard) => _users[guard];

  void login(String guard, Map<String, dynamic> user) {
    _users[guard] = Map<String, dynamic>.from(user);
  }

  void logout(String guard) {
    _users.remove(guard);
  }

  void clearAll() {
    _users.clear();
  }
}
