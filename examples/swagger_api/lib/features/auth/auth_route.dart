import 'package:vania/route.dart';
import 'package:swagger_api/features/auth/auth_controller.dart';
import 'package:swagger_api/features/auth/bearer_middleware.dart';

class AuthRoute extends Route {
  @override
  String? get prefix => 'api';

  @override
  void register() {
    super.register();

    Router.post('/login', authController.login);
    Router.get('/me', authController.me).middleware([BearerMiddleware()]);
  }
}
