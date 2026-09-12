import 'package:vania/route.dart';
import 'package:vania_auth/vania_auth.dart';
import 'package:basic_authentication/app/http/controllers/auth_controller.dart';

class ApiRoute extends Route {
  @override
  String? get prefix => 'api';

  @override
  void register() {
    super.register();

    // Public routes
    Router.post('/register', authController.register);
    Router.post('/login', authController.login);

    // Protected routes — require a valid bearer token
    Router.group(() {
      Router.get('/me', authController.me);
      Router.post('/logout', authController.logout);
    }, middleware: [Authenticate()]);
  }
}
