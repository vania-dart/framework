import 'package:vania/src/exception/redirect_exception.dart';
import 'package:vania/src/http/middleware/middleware.dart';
import 'package:vania/src/http/request/request.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/utils/helper.dart' show getSession;

class RedirectIfAuthenticated extends Middleware {
  final String path;
  RedirectIfAuthenticated({required this.path});

  @override
  Future handle(Request req) async {
    bool loggedIn = await getSession<bool?>('logged_in') ?? false;
    if (loggedIn) {
      throw RedirectException(
        message: path,
        responseType: ResponseType.html,
      );
    }
  }
}
