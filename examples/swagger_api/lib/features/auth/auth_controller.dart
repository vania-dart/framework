import 'package:vania/http/controller.dart';
import 'package:vania/http/request.dart';
import 'package:vania/http/response.dart';
import 'package:swagger_api/features/auth/auth_store.dart';

class AuthController extends Controller {
  Future<Response> login(Request req) async {
    await req.validate({
      'username': 'required|string',
      'password': 'required|string',
    });

    final token = authStore.login(
      req.input('username') as String,
      req.input('password') as String,
    );
    if (token == null) {
      return Response.json({'message': 'Invalid credentials'}, 401);
    }
    return Response.json({'token': token, 'token_type': 'Bearer'});
  }

  /// Protected by [BearerMiddleware]; `auth_user` was set there.
  Future<Response> me(Request req) async {
    return Response.json({'username': req.input('auth_user')});
  }
}

final AuthController authController = AuthController();
