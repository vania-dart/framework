import 'package:vania/http/controller.dart';
import 'package:vania/http/request.dart';
import 'package:vania/http/response.dart';
import 'package:vania_auth/vania_auth.dart';
import 'package:basic_authentication/app/models/user.dart';

class AuthController extends Controller {
  Future<Response> register(Request req) async {
    await req.validate({
      'name': 'required|string|max_length:100',
      'email': 'required|email|unique:users',
      'password': 'required|min_length:8|confirmed',
    });

    final user = await User().query.create({
      'name': req.input('name'),
      'email': req.input('email'),
      'password': Auth().hash.make(req.input('password')),
    });

    Auth().login(user);
    final token = await Auth().createToken(expiresIn: Duration(days: 30));

    return Response.json({
      'user': user,
      'token': token['access_token'],
    }, 201);
  }

  Future<Response> login(Request req) async {
    await req.validate({
      'email': 'required|email',
      'password': 'required',
    });

    final user =
        await User().query.where('email', '=', req.input('email')).first();

    if (user == null ||
        !Auth().hash.verify(req.input('password'), user['password'])) {
      return Response.json({'message': 'Invalid credentials'}, 401);
    }

    Auth().login(user);
    final token = await Auth().createToken(expiresIn: Duration(days: 30));

    return Response.json({
      'user': user,
      'token': token['access_token'],
    });
  }

  Future<Response> me(Request req) async {
    return Response.json(req.user);
  }

  Future<Response> logout(Request req) async {
    final authorization = req.header('authorization');
    if (authorization != null) {
      final token = authorization.replaceFirst('Bearer ', '');
      await Auth().revokeToken(token);
    }
    return Response.json({'message': 'Logged out'});
  }
}

final AuthController authController = AuthController();
