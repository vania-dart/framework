import 'package:vania/src/authentication/authentication_manager.dart';
import 'package:vania/src/authentication/token_handler/token_handler.dart';
import 'package:vania/src/authentication/user_repository.dart';
import 'package:vania/src/exception/invalid_argument_exception.dart';
import 'package:vania/src/exception/unauthenticated.dart';
import 'package:vania/vania.dart';

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
  @override
  AuthenticationManagerImpl guard(String guard) {
    _userGuard = guard;
    return this;
  }

  @override
  AuthenticationManagerImpl login(Map<String, dynamic> user) {
    _user[_userGuard] = user;
    return this;
  }

  @override
  bool get isAuthorized => _isAuthorized;

  @override
  Map<String, dynamic>? user() => _user[_userGuard];

  @override
  dynamic id() => _user[_userGuard]['id'] ?? _user[_userGuard]['_id'];

  @override
  dynamic get(String filed) => _user[_userGuard][filed];

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
