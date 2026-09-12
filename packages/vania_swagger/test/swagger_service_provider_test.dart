import 'package:test/test.dart';
import 'package:vania/route.dart' show Router;
import 'package:vania_swagger/vania_swagger.dart';

void main() {
  setUp(SwaggerMetadata().clear);

  group('SwaggerServiceProvider', () {
    test('boot() mounts three routes under the configured base path', () async {
      final before = Router().routes.length;

      final provider = SwaggerServiceProvider(
        config: const SwaggerConfig(basePath: '/api-docs', enabled: true),
        info: const ApiInfo(title: 'X', version: '1.0.0'),
      );
      await provider.register();
      await provider.boot();

      final paths = Router().routes.skip(before).map((r) => r.path).toSet();
      expect(
        paths,
        containsAll(<String>{
          '/api-docs',
          '/api-docs/swagger.json',
          '/api-docs/swagger.yaml',
        }),
      );
    });

    test('register() copies ApiInfo into SwaggerMetadata', () async {
      final provider = SwaggerServiceProvider(
        info: const ApiInfo(title: 'Y', version: '2.0.0'),
      );

      await provider.register();

      expect(SwaggerMetadata().apiInfo?.title, 'Y');
    });

    test('normalizedBasePath fixes trailing slash without crashing', () {
      const config = SwaggerConfig(basePath: '/docs/');
      expect(config.normalizedBasePath(), '/docs');
    });

    test('disabled config is a no-op at boot()', () async {
      final before = Router().routes.length;

      final provider = SwaggerServiceProvider(
        config: const SwaggerConfig(enabled: false),
      );
      await provider.register();
      await provider.boot();

      expect(Router().routes.length, before);
    });
  });

  group('encodeYaml', () {
    test('emits maps, lists, and scalars in a consumable shape', () {
      final yaml = encodeYaml({
        'openapi': '3.1.0',
        'paths': {
          '/pets': {
            'get': {'summary': 'List'},
          },
        },
        'tags': ['a', 'b'],
        'x-empty-map': const <String, Object>{},
      });
      expect(yaml, contains('openapi:'));
      expect(yaml, contains('3.1.0'));
      expect(yaml, contains('/pets'));
      expect(yaml, contains('get:'));
      expect(yaml, contains('summary: List'));
      expect(yaml, contains('- a'));
      expect(yaml, contains('- b'));
    });
  });
}
