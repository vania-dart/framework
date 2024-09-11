import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:meta/meta.dart';
import 'package:vania/src/authentication/authentication_manager.dart';
import 'package:vania/src/exception/unauthenticated.dart';
import 'package:vania/vania.dart';

class Authenticate extends Middleware {
  final AuthenticationManager auth;
  final String? guard;
  Authenticate({required this.auth, this.guard});

  @mustCallSuper
  @override
  handle(Request req) async {
    String? token = req.header('authorization')?.replaceFirst('Bearer ', '');
    try {
      if (guard == null) {
        await auth.check(token ?? '');
      } else {
        await auth.guard(guard!).check(token ?? '');
      }
    } on JWTExpiredException {
      throw Unauthenticated(message: 'Token expired');
    }
  }
}
