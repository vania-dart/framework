import 'package:vania/src/exception/invalid_argument_exception.dart';
import 'package:vania/src/exception/unauthenticated.dart';
import 'package:vania/vania.dart';

import 'has_api_tokens.dart';

class Auth {
  static final Auth _singleton = Auth._internal();
  factory Auth() => _singleton;
  Auth._internal();

  String _userGuard = 'default';

  bool _isAuthorized = false;

  final Map<String, dynamic> _user = {};

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

  dynamic id() => _user[_userGuard]['id'];

  dynamic get(String filed) => _user[_userGuard][filed];

  Map<String, dynamic> createToken(
      {Duration? expiresIn, bool withRefreshToken = false}) {
    return HasApiTokens()
        .setPayload(_user[_userGuard])
        .createToken(_userGuard, expiresIn, withRefreshToken);
  }

  Map<String, dynamic> createTokenByRefreshToken(String token,
      {Duration? expiresIn}) {
    return HasApiTokens()
        .refreshToken(token.replaceFirst('Bearer ', ''), _userGuard, expiresIn);
  }

  Future<bool> check(String token, {Map<String, dynamic>? user}) async {
    Map<String, dynamic> payload = HasApiTokens()
        .verify(token.replaceFirst('Bearer ', ''), _userGuard, 'access_token');

    if (user == null) {
      Model? authenticatable =
          Config().get('auth')['guards'][_userGuard]['provider'];

      if (authenticatable == null) {
        throw InvalidArgumentException('Authenticatable class not found');
      }
      user =
          await authenticatable.query().where('id', '=', payload['id']).first();
    }

    if (user != null) {
      _user[_userGuard] = user;
      _isAuthorized = true;
      return true;
    } else {
      throw Unauthenticated(message: 'Invalid token');
    }
  }
}
