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
    String guard = '',
    Duration? expiresIn,
  ]) {
    final jwt = JWT({'id': _userPayload?['id']});
    String token = jwt.sign(SecretKey('${Config().get('key')}$guard'),
        expiresIn: expiresIn ?? const Duration(hours: 24));
    return token;
  }

  String refreshToken(
    String token, [
    String guard = '',
    Duration? expiresIn,
  ]) {
    Map<String, dynamic> payload = JWT.decode(token).payload;
    final jwt = JWT({'id': payload['id']});
    String rTtoken = jwt.sign(SecretKey('${Config().get('key')}$guard'),
        expiresIn: expiresIn ?? const Duration(hours: 24));
    return rTtoken;
  }

  Map<String, dynamic> verify(String token, String guard) {
    try {
      final jwt = JWT.verify(token, SecretKey('${Config().get('key')}$guard'));
      return jwt.payload;
    } on JWTExpiredException {
      rethrow;
    } on JWTException {
      throw Unauthenticated(message: 'Invalid token');
    }
  }
}
