import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:vania/src/exception/unauthenticated.dart';
import 'package:vania/vania.dart';

class Authenticate extends Middleware {
  bool refreshToken;
  Authenticate([this.refreshToken = false]);

  @override
  handle(Request req) async {
    String? token = req.header('authorization')?.replaceFirst('Bearer ', '');
    try {
      await Auth().check(token ?? '');
      next?.handle(req);
    } on JWTExpiredException {
      if (refreshToken) {
        _tokenExpired(req, token!);
        rethrow;
      } else {
        throw Unauthenticated(message: 'Token expired');
      }
    }
  }

  void _tokenExpired(Request req, String token) {
    Duration expiresIn = Duration(hours: 24);
    String refreshToken =
        Auth().createRefreshToken(token, expiresIn: expiresIn);
    req.response.headers.contentType = ContentType.json;
    req.response.statusCode = HttpStatus.unauthorized;
    req.response.write(jsonEncode({
      'token': refreshToken,
      'message': 'refresh_token',
      'expires_in': DateTime.now().add(expiresIn).toIso8601String(),
    }));
    req.response.close();
  }
}
