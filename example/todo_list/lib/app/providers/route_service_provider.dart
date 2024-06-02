import 'package:todo_list/route/api_first_version.dart';
import 'package:vania/vania.dart';
import 'package:todo_list/route/api_route.dart';
import 'package:todo_list/route/web.dart';

class RouteServiceProvider extends ServiceProvider {
  @override
  Future<void> boot() async {}

  @override
  Future<void> register() async {
    WebRoute().register();
    ApiRoute().register();
    ApiFirstVersion().register();
  }
}
