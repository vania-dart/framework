import 'package:vania/route.dart';
import 'package:redis_cache/features/views/views_controller.dart';

class ViewsRoute extends Route {
  @override
  String? get prefix => 'api';

  @override
  void register() {
    super.register();

    Router.post('/views/{page}', viewsController.record);
    Router.get('/views/{page}', viewsController.show);
  }
}
