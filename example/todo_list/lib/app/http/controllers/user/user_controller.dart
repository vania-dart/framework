import 'package:vania/vania.dart';

import '../../../models/user.dart';

class UserController extends Controller {
  /// Fetch user details
  Future<Response> index() async {
    Map<String, dynamic>? details =
        await User().query().where('id', '=', Auth().id()).first();

    return Response.json(details);
  }

  /// Update curent user details
  Future<Response> update(Request request) async {
    request.validate({
      'first_name': 'required|max_length:20|min_length:2',
      'last_name': 'required|max_length:20',
      'email': 'required|email',
      'avatar': 'file:jpg,jpeg,png',
    }, {
      'first_name.required': 'The first name is required',
      'first_name.max_length': 'The first name must be less than 20 characters',
      'first_name.min_length': 'The first name must be at least 2 characters',
      'last_name.required': 'The last name is required',
      'last_name.max_length': 'The last name must be less than 20 characters',
      'email.required': 'The email is required',
      'email.email': 'The email is not valid',
      'avatar.file': 'The avatar must be an image file',
    });

    /// Upload avtar if is sent
    RequestFile? avatar = request.file('avatar');
    String avatarPath = '';

    // If you have guard you can get user id by guard ex: Auth().guard('admin').id()
    if (avatar != null) {
      /// The file will be stored in the storage/app/public/user/user_id folder
      avatarPath = await avatar.store(
          path: 'users/${Auth().id()}', filename: avatar.filename);
    }

    await User().query().where('id', '=', Auth().id()).update({
      'first_name': request.input('first_name'),
      'last_name': request.input('last_name'),
      'email': request.input('email'),
      'avatar': avatarPath,
    });

    return Response.json({'message': 'User updated successfully'});
  }
}

final UserController userController = UserController();
