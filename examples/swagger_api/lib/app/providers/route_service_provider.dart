import 'package:vania/route.dart' show Router;
import 'package:vania/service_provider.dart';
import 'package:swagger_api/features/products/products_route.dart';
import 'package:swagger_api/features/auth/auth_route.dart';
import 'package:swagger_api/docs/api_docs.dart';

class RouteServiceProvider extends ServiceProvider {
  @override
  Future<void> register() async {}

  @override
  Future<void> boot() async {
    ProductsRoute().register();
    AuthRoute().register();

    // A `Route` with a prefix sets a sticky global base prefix on the
    // Router. Clear it so the SwaggerServiceProvider (which boots next and
    // registers `/docs` directly) isn't pushed under `/api`.
    Router.basePrefix(null);

    registerApiDocs();
  }
}
