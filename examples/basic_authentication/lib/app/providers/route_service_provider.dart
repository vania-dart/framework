import 'package:vania/service_provider.dart';
import 'package:basic_authentication/route/api_route.dart';

class RouteServiceProvider extends ServiceProvider {
  @override
  Future<void> register() async {}

  @override
  Future<void> boot() async {
    ApiRoute().register();
  }
}
