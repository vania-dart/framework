import 'package:vania/service_provider.dart';
import 'package:redis_cache/features/views/views_route.dart';

class RouteServiceProvider extends ServiceProvider {
  @override
  Future<void> register() async {}

  @override
  Future<void> boot() async {
    ViewsRoute().register();
  }
}
