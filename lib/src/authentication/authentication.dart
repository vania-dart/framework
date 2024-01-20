import 'package:vania/src/database/model.dart';
import 'package:vania/src/exception/unauthenticated.dart';
import 'package:vania/vania.dart';

import 'has_api_tokens.dart';

class Auth {
  static final Auth _singleton = Auth._internal();
  factory Auth() => _singleton;
  Auth._internal();

  String _userGuard = 'default';

  //Auth([String guard = 'default']) : _userGuard = guard;

  final Map<String, dynamic> _user = {};

  Auth guard(String guard) {
    _userGuard = guard;
    return this;
  }

  Auth login(Map<String, dynamic> user) {
    _user[_userGuard] = user;
    return this;
  }

  Map<String, dynamic>? user() => _user[_userGuard];

  dynamic id() => _user[_userGuard]['id'];

  dynamic get(String filed) => _user[_userGuard][filed];

  String createToken({Duration? expiresIn}) {
    return HasApiTokens().setPayload(_user[_userGuard]).createToken(expiresIn);
  }

  String createRefreshToken(String token,{Duration? expiresIn}) {
    return HasApiTokens().refreshToken(token,expiresIn);
  }

  Future<bool> check(Model authenticatable, String token) async {
      Map<String, dynamic> payload = HasApiTokens().verify(token);
      Map<String, dynamic>? user =
          await authenticatable.query().where('id', '=', payload['id']).first();
      if (user != null) {
        _user[_userGuard] = user;
        return true;
      } else {
        throw Unauthenticated(message: 'Invalid token');
      }
  }
}
