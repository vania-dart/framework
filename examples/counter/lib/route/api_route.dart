import 'package:vania/route.dart';
import 'package:counter/app/http/controllers/counter_controller.dart';

class ApiRoute extends Route {
  @override
  String? get prefix => 'api';

  @override
  void register() {
    super.register();

    Router.get('/counter', counterController.show);
    Router.post('/counter/increment', counterController.increment);
    Router.post('/counter/decrement', counterController.decrement);
    Router.post('/counter/reset', counterController.reset);
  }
}
