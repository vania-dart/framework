import 'package:vania/service_provider.dart';
import 'package:todos/modules.dart';

class RouteServiceProvider extends ServiceProvider {
  @override
  Future<void> register() async {}

  @override
  Future<void> boot() async {
    for (final module in modules) {
      module.register();
    }
  }
}
