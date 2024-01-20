import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:vania/src/config/config.dart';
import 'package:vania/src/exception/unauthenticated.dart';

class HasApiTokens {
  static final HasApiTokens _singleton = HasApiTokens._internal();
  factory HasApiTokens() => _singleton;
  HasApiTokens._internal();

  Map<String, dynamic>? _userPayload = {};

  HasApiTokens setPayload(Map<String, dynamic> payload) {
    _userPayload = payload;
    return this;
  }

  String createToken([
    Duration? expiresIn,
  ]) {
    final jwt = JWT({'id': _userPayload?['id']});
    String token =
        jwt.sign(SecretKey(Config().get('key')), expiresIn: expiresIn ?? const Duration(hours: 24));
    return token;
  }

  Map<String, dynamic> verify(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(Config().get('key')));
      return jwt.payload;
    } on JWTExpiredException {
      throw Unauthenticated(message:  'token expired');
    } on JWTException {
      throw Unauthenticated(message:  'Invalid token');
    }
  }
}
