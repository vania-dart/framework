import 'package:vania/vania.dart' show Unauthenticated;
import 'package:vania/http/middleware.dart';
import 'package:vania/http/request.dart';
import 'package:swagger_api/features/auth/auth_store.dart';

/// Rejects the request unless it carries a valid
/// `Authorization: Bearer {token}` header. On success it stashes the
/// username so the controller can read it via `req.input('auth_user')`.
class BearerMiddleware extends Middleware {
  @override
  Future<void> handle(Request req) async {
    final header = req.header('authorization') ?? '';
    if (!header.startsWith('Bearer ')) {
      throw Unauthenticated(message: 'Missing bearer token');
    }
    final username = authStore.userFor(header.substring('Bearer '.length));
    if (username == null) {
      throw Unauthenticated(message: 'Invalid or expired token');
    }
    req.merge({'auth_user': username});
  }
}
