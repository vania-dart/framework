import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:meta/meta.dart';
import 'package:vania/src/exception/unauthenticated.dart';
import 'package:vania/vania.dart';

class Authenticate extends Middleware {
  final String? guard;
  final bool basic;
  final String loginPath;
  Authenticate({
    this.guard,
    this.basic = false,
    this.loginPath = '/login',
  });

  @mustCallSuper
  @override
  handle(Request req) async {
    if (basic) {
      bool loggedIn = await getSession<bool?>('logged_in') ?? false;
      if (loggedIn) {
        String guard = await getSession<String?>('auth_guard') ?? '';
        Map<String, dynamic> user =
            await getSession<Map<String, dynamic>?>('auth_user') ?? {};
        Auth().guard(guard).login(user);
      } else {
        throw Unauthenticated(
          message: loginPath,
          responseType: ResponseType.html,
        );
      }
    } else {
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
}
