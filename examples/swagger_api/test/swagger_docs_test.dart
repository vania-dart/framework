import 'package:test/test.dart';
import 'package:vania_swagger/vania_swagger.dart';
import 'package:swagger_api/docs/api_docs.dart';

void main() {
  group('OpenAPI spec', () {
    late Map<String, dynamic> spec;

    setUp(() {
      swaggerInfo(const ApiInfo(title: 'Products API', version: '1.0.0'));
      registerApiDocs();
      spec = SwaggerGenerator().generate();
    });

    test('reports OpenAPI 3.x and the api info', () {
      expect(spec['openapi'].toString(), startsWith('3.'));
      expect((spec['info'] as Map)['title'], 'Products API');
    });

    test('documents every products path', () {
      final paths = spec['paths'] as Map<String, dynamic>;
      expect(paths.keys, containsAll(['/api/products', '/api/products/{id}']));
    });

    test('lists and creates are documented on the collection path', () {
      final collection = (spec['paths'] as Map)['/api/products'] as Map;
      expect(collection.keys, containsAll(['get', 'post']));
      expect((collection['post'] as Map)['summary'], 'Create a product');
    });

    test('exposes the reusable Product schema', () {
      final schemas =
          ((spec['components'] as Map)['schemas'] as Map<String, dynamic>);
      expect(schemas.keys, contains('Product'));
      final props = (schemas['Product'] as Map)['properties'] as Map;
      expect(props.keys, containsAll(['id', 'name', 'price_cents']));
    });
  });
}
