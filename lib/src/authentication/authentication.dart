import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:vania/src/exception/invalid_argument_exception.dart';
import 'package:vania/src/exception/unauthenticated.dart';
import 'package:vania/vania.dart';

import 'model/personal_access_token.dart';

class Auth {
  static final Auth _singleton = Auth._internal();
  factory Auth() => _singleton;
  Auth._internal();

  String _userGuard = 'default';

  bool _isAuthorized = false;

  String _currentToken = '';

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

  dynamic id() => _user[_userGuard]['id'] ?? _user[_userGuard]['_id'];

  dynamic get(String filed) => _user[_userGuard][filed];

  Future<Map<String, dynamic>> createToken({
    Duration? expiresIn,
    bool withRefreshToken = false,
    bool customToken = false,
  }) async {
    Map<String, dynamic> token = HasApiTokens()
        .setPayload(_user[_userGuard])
        .createToken(_userGuard, expiresIn, withRefreshToken);

    if (!customToken) {
      await PersonalAccessTokens().query().insert({
        'name': _userGuard,
        'tokenable_id': _user[_userGuard]['id'],
        'token': md5.convert(utf8.encode(token['access_token'])),
        'created_at': DateTime.now(),
      });
    }

    return token;
  }

  Map<String, dynamic> createTokenByRefreshToken(
    String token, {
    Duration? expiresIn,
  }) {
    return HasApiTokens().refreshToken(
      token.replaceFirst('Bearer ', ''),
      _userGuard,
      expiresIn,
    );
  }

  Future<bool> deleteTokens() async {
    await PersonalAccessTokens()
        .query()
        .where('tokenable_id', '=', _user[_userGuard]['id'])
        .update({'deleted_at': DateTime.now()});

    return true;
  }

  Future<bool> deleteCurrentToken() async {
    await PersonalAccessTokens()
        .query()
        .where('token', '=', md5.convert(utf8.encode(_currentToken)))
        .update({'deleted_at': DateTime.now()});
    return true;
  }

  Future<bool> check(
    String token, {
    Map<String, dynamic>? user,
    bool isCustomToken = false,
  }) async {
    Map<String, dynamic> payload = HasApiTokens()
        .verify(token.replaceFirst('Bearer ', ''), _userGuard, 'access_token');

    if (isCustomToken) {
      _user[_userGuard] = payload;
      _isAuthorized = true;
      _currentToken = token;
      return true;
    } else {
      Map<String, dynamic>? exists = await PersonalAccessTokens()
          .query()
          .where('token', '=', md5.convert(utf8.encode(token)))
          .whereNull('deleted_at')
          .first(['id']);
      // Throw 401 Error if token not found
      if (exists == null) {
        throw Unauthenticated(message: 'Invalid token');
      }

      await PersonalAccessTokens()
          .query()
          .where('token', '=', md5.convert(utf8.encode(token)))
          .update({'last_used_at': DateTime.now()});

      if (user == null) {
        Model? authenticatable =
            Config().get('auth')['guards'][_userGuard]['provider'];

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
