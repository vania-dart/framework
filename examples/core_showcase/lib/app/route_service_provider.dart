import 'package:vania/service_provider.dart';

import '../route/api_route.dart';
import '../route/web_route.dart';

class RouteServiceProvider extends ServiceProvider {
  @override
  Future<void> register() async {}

  @override
  Future<void> boot() async {
    ApiRoute().register();
    WebRoute().register();
  }
}
