import 'package:vania/route.dart';
import 'package:swagger_api/features/products/product_controller.dart';

class ProductsRoute extends Route {
  @override
  String? get prefix => 'api';

  @override
  void register() {
    super.register();

    Router.get('/products', productController.index);
    Router.post('/products', productController.store);
    Router.get('/products/{id}', productController.show).whereInt('id');
    Router.delete('/products/{id}', productController.destroy).whereInt('id');
  }
}
