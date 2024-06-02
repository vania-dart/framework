import 'package:todo_list/app/http/controllers/auth/auth_controller.dart';
import 'package:todo_list/app/http/controllers/user/user_controller.dart';
import 'package:todo_list/app/http/middleware/authenticate.dart';
import 'package:vania/vania.dart';

class ApiFirstVersion extends Route {
  @override
  void register() {
    Router.basePrefix('api/v1');

    Router.group(
      () {
        Router.post('login', authController.login);
        Router.post('sign-up', authController.signUp);
        Router.post('refresh-token', authController.refreshToken);
      },
      prefix: 'auth',
    );
    Router.group(
      () {
        Router.get('info', userController.index);
        Router.patch('update', userController.update);
      },
      prefix: 'user',
      middleware: [AuthenticateMiddleware()],
    );
  }
}
