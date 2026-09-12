import 'package:vania/service_provider.dart';
import 'package:elasticsearch_search/features/search/search_route.dart';

class RouteServiceProvider extends ServiceProvider {
  @override
  Future<void> register() async {}

  @override
  Future<void> boot() async {
    SearchRoute().register();
  }
}
