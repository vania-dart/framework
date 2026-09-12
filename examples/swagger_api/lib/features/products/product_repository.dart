import 'package:swagger_api/features/products/product.dart';

/// In-memory product store, seeded with one item.
class ProductRepository {
  final Map<int, Product> _items = {};
  int _seq = 0;

  ProductRepository() {
    create('Coffee mug', 1200);
  }

  List<Product> all() => _items.values.toList();

  Product? find(int id) => _items[id];

  Product create(String name, int priceCents) {
    final product = Product(id: ++_seq, name: name, priceCents: priceCents);
    _items[product.id] = product;
    return product;
  }

  bool delete(int id) => _items.remove(id) != null;
}

final ProductRepository productRepository = ProductRepository();
