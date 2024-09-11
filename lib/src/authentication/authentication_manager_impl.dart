import 'package:vania/src/authentication/authentication_manager.dart';
import 'package:vania/src/authentication/token_handler/token_handler.dart';
import 'package:vania/src/authentication/user_repository.dart';
import 'package:vania/src/exception/invalid_argument_exception.dart';
import 'package:vania/src/exception/unauthenticated.dart';
import 'package:vania/vania.dart';

/// Manages authentication processes, including token management, user sessions, and authentication states.
class AuthenticationManagerImpl implements AuthenticationManager {
  final TokenHandler tokenHandler;
  final UserRepository userRepository;
  final Config config;
  String _userGuard = 'default';
  bool _isAuthorized = false;
  String _currentToken = '';
  final Map<String, dynamic> _user = {};

  AuthenticationManagerImpl(this.config,
      {required this.tokenHandler, required this.userRepository});

  /// Sets the guard for the current authentication process.
  ///
  /// [guard] is a string key representing the guard.
  /// Returns this `AuthenticationManagerImpl` instance for method chaining.
  ///
  /// Example:
  /// ```
  /// var authManager = AuthenticationManagerImpl(config, tokenHandler: tokenHandler, userRepository: userRepository);
  /// authManager.guard('admin');
  /// ```
  @override
  AuthenticationManagerImpl guard(String guard) {
    _userGuard = guard;
    return this;
  }

  /// Logs in a user by setting the user information for the current guard.
  ///
  /// [user] is a map containing the user details.
  /// Returns this `AuthenticationManagerImpl` instance for method chaining.
  ///
  /// Example:
  /// ```
  /// var user = {'id': 1, 'name': 'John Doe'};
  /// authManager.login(user);
  /// ```
  @override
  AuthenticationManagerImpl login(Map<String, dynamic> user) {
    _user[_userGuard] = user;
    return this;
  }

  /// Checks if a user is currently authorized.
  ///
  /// Returns `true` if the user is authorized, otherwise `false`.
  ///
  /// Example:
  /// ```
  /// if (authManager.isAuthorized) {
  ///   print('User is authorized.');
  /// }
  /// ```
  @override
  bool get isAuthorized => _isAuthorized;

  /// Retrieves the user details for the current guard.
  ///
  /// Returns a map of user details if logged in, otherwise `null`.
  ///
  /// Example:
  /// ```
  /// var userDetails = authManager.user();
  /// print(userDetails);
  /// ```
  @override
  Map<String, dynamic>? user() => _user[_userGuard];

  /// Retrieves the unique identifier of the currently logged-in user.
  ///
  /// Returns the user identifier.
  ///
  /// Example:
  /// ```
  /// var userId = authManager.id();
  /// print('User ID: $userId');
  /// ```
  @override
  dynamic id() => _user[_userGuard]['id'] ?? _user[_userGuard]['_id'];

  /// Retrieves a specific field value from the currently logged-in user's details.
  ///
  /// [field] is a string specifying the field to retrieve.
  /// Returns the value of the specified field.
  ///
  /// Example:
  /// ```
  /// var userName = authManager.get('name');
  /// print('User Name: $userName');
  /// ```
  @override
  dynamic get(String filed) => _user[_userGuard][filed];

  /// Creates a new authentication token for the currently logged-in user.
  ///
  /// Optional parameters:
  /// [expiresIn] customizes the expiration of the token.
  /// [withRefreshToken] indicates whether a refresh token should also be generated.
  /// [customToken] specifies if the token should be stored or managed in a custom way.
  ///
  /// Returns a `Future` that resolves to a map containing token details.
  ///
  /// Example:
  /// ```
  /// var tokenDetails = await authManager.createToken();
  /// print(tokenDetails);
  /// ```
  @override
  Future<Map<String, dynamic>> createToken({
    Duration? expiresIn,
    bool withRefreshToken = false,
    bool customToken = false,
  }) async {
    Map<String, dynamic> token = tokenHandler
        .setPayload(_user[_userGuard])
        .createToken(
            guard: _userGuard,
            expiresIn: expiresIn,
            withRefreshToken: withRefreshToken);

    if (!customToken) {
      await userRepository.storeToken(
        name: _userGuard,
        userId: _user[_userGuard]['id'],
        token: token['access_token'],
        createdAt: DateTime.now(),
      );
    }
    return token;
  }

  dynamic _getAuthenticatableStatus() {
    try {
      return config.get('auth')['guards'][_userGuard]['provider'];
    } catch (_) {
      return InvalidArgumentException('Authenticatable class not found');
    }
  }

  Future<dynamic> _verifyTokenAndLoadUser(String token, String type) async {
    var payload = tokenHandler.verify(
        token.replaceFirst('Bearer ', ''), _userGuard, type);
    var user = await _loadUserFromPayload(payload);
    if (user == null) {
      throw Unauthenticated(message: 'Invalid token');
    }
    return user;
  }

  Future<dynamic> _loadUserFromPayload(Map<String, dynamic> payload) async {
    Model? authenticatable = _getAuthenticatableStatus();
    return await authenticatable!
        .query()
        .where('id', '=', payload['id'])
        .first();
  }

  @override
  Future<Map<String, dynamic>> createTokenByRefreshToken(
    String token, {
    Duration? expiresIn,
    bool customToken = false,
  }) async {
    final newToken = tokenHandler.refreshToken(
      token.replaceFirst('Bearer ', ''),
      _userGuard,
      expiresIn,
    );

    if (!customToken) {
      Map? user = await _verifyTokenAndLoadUser(token, 'refresh_token');

      if (user == null) {
        throw Unauthenticated(message: 'Invalid token');
      }

      _user[_userGuard] = user;
      await userRepository.storeToken(
        name: _userGuard,
        userId: user['id'],
        token: newToken['access_token'],
        createdAt: DateTime.now(),
      );
    }

    return newToken;
  }

  @override
  Future<bool> deleteTokens() async {
    await userRepository.deleteTokenById(_user[_userGuard]['id']);
    return true;
  }

  @override
  Future<bool> deleteCurrentToken() async {
    await userRepository.deleteTokenByToken(_currentToken);
    return true;
  }

  @override
  Future<bool> check(
    String token, {
    Map<String, dynamic>? user,
    bool isCustomToken = false,
  }) async {
    Map<String, dynamic> payload = tokenHandler.verify(
        token.replaceFirst('Bearer ', ''), _userGuard, 'access_token');

    if (isCustomToken) {
      _user[_userGuard] = payload;
      _isAuthorized = true;
      _currentToken = token;
      return true;
    } else {
      Map<String, dynamic>? userMap =
          await userRepository.findUserByToken(token);
      // Throw 401 Error if token not found
      if (userMap == null) {
        throw Unauthenticated(message: 'Invalid token');
      }

      if (user == null) {
        Model? authenticatable = _getAuthenticatableStatus();

        user = await authenticatable!
            .query()
            .where('id', '=', payload['id'])
            .first();
      }

      if (user != null) {
        _user[_userGuard] = user;
        _isAuthorized = true;
        _currentToken = token;
        return true;
      } else {
        throw Unauthenticated(message: 'Invalid token');
      }
    }
  }
}
