import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:meta/meta.dart';
import 'package:vania/src/exception/unauthenticated.dart';
import 'package:vania/vania.dart';

class Authenticate extends Middleware {
  @mustCallSuper
  @override
  handle(Request req) async {
    String? token = req.header('authorization')?.replaceFirst('Bearer ', '');
    try {
      await Auth().check(token ?? '');
      next?.handle(req);
    } on JWTExpiredException {
      throw Unauthenticated(message: 'Token expired');
    }
  }
}
