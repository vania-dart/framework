import 'package:test/test.dart';
import 'package:swagger_api/features/products/product_repository.dart';

void main() {
  group('ProductRepository', () {
    late ProductRepository repo;

    setUp(() {
      repo = ProductRepository();
    });

    test('is seeded with one product', () {
      expect(repo.all(), hasLength(1));
    });

    test('create adds a product with an incrementing id', () {
      final created = repo.create('Notebook', 500);
      expect(created.id, 2);
      expect(repo.all(), hasLength(2));
    });

    test('find returns the product by id', () {
      final created = repo.create('Pen', 150);
      expect(repo.find(created.id)!.name, 'Pen');
    });

    test('delete removes a product', () {
      final created = repo.create('Eraser', 90);
      expect(repo.delete(created.id), isTrue);
      expect(repo.find(created.id), isNull);
    });

    test('toJson exposes the public shape', () {
      final json = repo.create('Ruler', 300).toJson();
      expect(json.keys, containsAll(['id', 'name', 'price_cents']));
    });
  });
}
