import 'package:vania/src/authentication/token_handler.dart';
import 'package:vania/src/authentication/user_repository.dart';
import 'package:vania/src/exception/invalid_argument_exception.dart';
import 'package:vania/src/exception/unauthenticated.dart';
import 'package:vania/vania.dart';


class Auth {
  final TokenHandler tokenHandler;
  final UserRepository userRepository;
  final Config config;
  String _userGuard = 'default';
  bool _isAuthorized = false;
  String _currentToken = '';
  final Map<String, dynamic> _user = {};

  Auth(this.config, {required this.tokenHandler, required this.userRepository});

  Auth guard(String guard) {
    _userGuard = guard;
    return this;
  }

  Auth login(Map<String, dynamic> user) {
    _user[_userGuard] = user;
    return this;
  }

  bool get isAuthorized => _isAuthorized;

  Map<String, dynamic>? user() => _user[_userGuard];

  dynamic id() => _user[_userGuard]['id'] ?? _user[_userGuard]['_id'];

  dynamic get(String filed) => _user[_userGuard][filed];

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
      Map<String, dynamic> payload = tokenHandler.verify(
          token.replaceFirst('Bearer ', ''), _userGuard, 'refresh_token');
      Model? authenticatable;
      try {
        authenticatable = config.get('auth')['guards'][_userGuard]['provider'];
      } catch (_) {}

      if (authenticatable == null) {
        throw InvalidArgumentException('Authenticatable class not found');
      }

      Map? user =
          await authenticatable.query().where('id', '=', payload['id']).first();

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

  Future<bool> deleteTokens() async {
    await userRepository.deleteTokenById(_user[_userGuard]['id']);
    return true;
  }

  Future<bool> deleteCurrentToken() async {
    await userRepository.deleteTokenByToken(_currentToken);
    return true;
  }

  Future<bool> check(
    String token, {
    Map<String, dynamic>? user,
    bool isCustomToken = false,
  }) async {
    Map<String, dynamic> payload = tokenHandler
        .verify(token.replaceFirst('Bearer ', ''), _userGuard, 'access_token');

    if (isCustomToken) {
      _user[_userGuard] = payload;
      _isAuthorized = true;
      _currentToken = token;
      return true;
    } else {
      Map<String, dynamic>? exists = await userRepository.findUserByToken(token);
      // Throw 401 Error if token not found
      if (exists == null) {
        throw Unauthenticated(message: 'Invalid token');
      }

    
      if (user == null) {
        Model? authenticatable =
            config.get('auth')['guards'][_userGuard]['provider'];

        if (authenticatable == null) {
          throw InvalidArgumentException('Authenticatable class not found');
        }
        user = await authenticatable
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
