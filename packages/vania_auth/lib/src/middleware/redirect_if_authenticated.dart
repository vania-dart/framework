import 'package:vania/http/middleware.dart';
import 'package:vania/http/request.dart';
import 'package:vania/http/response.dart';
import 'package:vania/vania.dart';

/// Framework-integrated middleware for auth-guest routes (login/register).
/// When the incoming request already has an authenticated session, the user
/// is redirected to [path] instead of being allowed onto the guest page.
class RedirectIfAuthenticated extends Middleware {
  RedirectIfAuthenticated({required this.path});

  final String path;

  @override
  Future<void> handle(Request req) async {
    final loggedIn = await getSession<bool?>('logged_in') ?? false;
    if (loggedIn) {
      throw RedirectException(message: path, responseType: ResponseType.html);
    }
  }
}
