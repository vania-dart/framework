import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:meta/meta.dart';
import 'package:vaniaFramework/src/exception/unauthenticated.dart';
import 'package:vaniaFramework/vania_framework.dart';

class Authenticate extends Middleware {
  final String? guard;
  Authenticate({this.guard});

  @mustCallSuper
  @override
  handle(Request req) async {
    String? token = req.header('authorization')?.replaceFirst('Bearer ', '');
    try {
      if (guard == null) {
        await Auth().check(token ?? '');
      } else {
        await Auth().guard(guard!).check(token ?? '');
      }
    } on JWTExpiredException {
      throw Unauthenticated(message: 'Token expired');
    }
  }
}
