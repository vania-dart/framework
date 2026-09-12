import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:meta/meta.dart';
import 'package:vania/http/middleware.dart';
import 'package:vania/http/request.dart';
import 'package:vania/http/response.dart';
import 'package:vania/vania.dart';

import '../auth/auth.dart';
import '../jwt/jwt_service.dart' show JwtAuthException;

/// Framework-integrated auth middleware. Attach to any route via
/// `Router.get(...).middleware([Authenticate()])`. Extends core's [Middleware]
/// so it plugs into the same pre-middleware chain as CSRF/throttling.
///
/// * When [basic] is true, we read `logged_in` / `auth_guard` / `auth_user`
///   from the session (populated by a login controller).
/// * Otherwise we treat this as an API request: the `Authorization: Bearer …`
///   header is validated through [Auth.check].
class Authenticate extends Middleware {
  Authenticate({this.guard, this.basic = false, this.loginPath = '/login'});

  final String? guard;
  final bool basic;
  final String loginPath;

  @mustCallSuper
  @override
  Future handle(Request req) async {
    if (basic) {
      await _handleSession();
      return;
    }
    await _handleToken(req);
  }

  Future<void> _handleSession() async {
    final loggedIn = await getSession<bool?>('logged_in') ?? false;
    final sessionGuard = await getSession<String?>('auth_guard') ?? '';
    if (!loggedIn || sessionGuard.isEmpty) {
      throw Unauthenticated(
        message: loginPath,
        responseType: ResponseType.html,
      );
    }
    final rawUser =
        await getSession<Map<String, dynamic>?>('auth_user') ?? const {};
    final userForGuard = rawUser[sessionGuard];
    if (userForGuard is Map<String, dynamic>) {
      Auth().guard(sessionGuard).login(userForGuard);
    }
  }

  Future<void> _handleToken(Request req) async {
    final token = req.header('authorization')?.replaceFirst('Bearer ', '');
    if (token == null || token.isEmpty) {
      throw Unauthenticated(message: 'Unauthenticated');
    }

    try {
      final auth = guard == null ? Auth() : Auth().guard(guard!);
      await auth.check(token);
    } on JWTExpiredException {
      throw Unauthenticated(message: 'Token expired');
    } on JwtAuthException {
      // Revoked / unknown / wrong-type token, or a user row that no longer
      // exists. All of these are "you are not authenticated" — surface 401,
      // not the internal reason. Leaking which of the four it was tells an
      // attacker whether a token hash exists in the store.
      throw Unauthenticated(message: 'Unauthenticated');
    } on JWTException {
      // Malformed token, bad signature, wrong algorithm.
      throw Unauthenticated(message: 'Unauthenticated');
    }
  }
}
