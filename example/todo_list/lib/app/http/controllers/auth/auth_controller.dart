import 'dart:math';

import 'package:todo_list/app/models/user.dart';
import 'package:vania/vania.dart';


class AuthController extends Controller {
  /// Login
  Future<Response> login(Request request) async {
    request.validate({
      'email': 'required|email',
      'password': 'required',
    }, {
      'email.required': 'The email is required',
      'email.email': 'The email is not valid',
      'password.required': 'The password is required',
    });

    String email = request.input('email');
    String password = request.input('password').toString();

    final user = await User().query().where('email', email).first();

    if (user == null) {
      return Response.json({'message': 'User not found'});
    }

    if (!Hash().verify(password, user['password'])) {
      return Response.json({'message': 'Wrong password'});
    }

    // If you have guard and multi access like user and admin you can pass the guard Auth().guard('admin')
    Map<String, dynamic> token = await Auth()
        .login(user)
        .createToken(expiresIn: Duration(hours: 24), withRefreshToken: true);

    return Response.json(token);
  }

  /// Creating new user
  Future<Response> signUp(Request request) async {
    request.validate({
      'first_name': 'required|max_length:20|min_length:2',
      'last_name': 'required|max_length:20',
      'email': 'required|email',
      'password': 'required',
    }, {
      'first_name.required': 'The first name is required',
      'first_name.max_length': 'The first name must be less than 20 characters',
      'first_name.min_length': 'The first name must be at least 2 characters',
      'last_name.required': 'The last name is required',
      'last_name.max_length': 'The last name must be less than 20 characters',
      'email.required': 'The email is required',
      'email.email': 'The email is not valid',
      'password.required': 'The password is required',
    });

    /// Checking if the user already exists
    Map<String, dynamic>? user = await User()
        .query()
        .where('email', '=', request.input('email'))
        .first();
    if (user != null) {
      return Response.json({'message': 'User already exists'});
    }

    await User().query().insert({
      'first_name': request.input('first_name'),
      'last_name': request.input('last_name'),
      'email': request.input('email'),
      'password': Hash().make(request.input('password').toString()),
      'created_at': DateTime.now(),
      'updated_at': DateTime.now(),
    });

    return Response.json({'message': 'User created successfully'});
  }

  Future<Response> otp(Request request) {
    Random rnd = Random();
    int otp = rnd.nextInt(999999 - 111111);

    Cache.put('otp', otp.toString(), duration: Duration(minutes: 3));

    return Response.json({'message': 'OTP sent successfully'});
  }

  Future<Response> verifyOTO(Request request) async {
    final String otp = request.input('otp');
    final String otpValue = Cache.get('otp') as String;

    if (otpValue == otp) {
      Cache.delete('otp');
      return Response.json({'message': 'OTP verified successfully'});
    } else {
      return Response.json(
        {'message': 'Invalid OTP'},
        400,
      );
    }
  }

  /// Generating a new token if the accessToken is expired
  Future<Response> refreshToken(Request request) {
    final newToken = Auth().createTokenByRefreshToken(
        request.header('Authorization')!,
        expiresIn: Duration(hours: 24));
    return Response.json(newToken);
  }
}

final AuthController authController = AuthController();
