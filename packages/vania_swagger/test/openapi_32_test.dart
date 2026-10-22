import 'package:test/test.dart';
import 'package:vania_swagger/vania_swagger.dart';

void main() {
  setUp(() => SwaggerMetadata().clear());

  test('the spec declares OpenAPI 3.2.0', () {
    expect(SwaggerGenerator().generate()['openapi'], '3.2.0');
  });

  group('QUERY operations', () {
    test('swaggerQuery documents a QUERY next to the GET of its path', () {
      swaggerGet('/contacts', operation: const ApiOperation(summary: 'List'));
      swaggerQuery(
        '/contacts',
        operation: const ApiOperation(summary: 'Search'),
        body: const ApiBody(
          description: 'The query',
          rawSchema: {'type': 'object'},
        ),
        consumes: ['application/json', 'application/sql'],
      );

      final path = SwaggerGenerator().generate()['paths']['/contacts'] as Map;
      expect(path['get']['summary'], 'List');
      final query = path['query'] as Map;
      expect(query['summary'], 'Search');
      expect((query['requestBody']['content'] as Map).keys, [
        'application/json',
        'application/sql',
      ]);
    });

    test('a route registered with method QUERY lands in the query field', () {
      SwaggerModule.registerRoute(method: 'query', path: '/reports');
      final path = SwaggerGenerator().generate()['paths']['/reports'] as Map;
      expect(path.keys, ['query']);
    });

    test('ApiQueryMethod names the QUERY method, and leaves ApiQuery to '
        'query-string parameters', () {
      const route = ApiQueryMethod('/contacts');
      expect(route.method, 'QUERY');
      expect(route.path, '/contacts');
      expect(const ApiQuery(name: 'page').name, 'page');
    });
  });

  test('a method with no field of its own goes under additionalOperations, '
      'named as it is sent', () {
    SwaggerModule.registerRoute(method: 'PURGE', path: '/cache');
    SwaggerModule.registerRoute(method: 'DELETE', path: '/cache');

    final path = SwaggerGenerator().generate()['paths']['/cache'] as Map;
    expect(path.containsKey('purge'), isFalse);
    expect((path['additionalOperations'] as Map).keys, ['PURGE']);
    expect(path.containsKey('delete'), isTrue);
  });

  test('both Swagger UI pages load one bundle version, recent enough to '
      'render 3.2 and try QUERY out', () {
    final versions = {
      for (final page in [
        SwaggerPage.render(specUrl: '/docs.json'),
        SwaggerPageRenderer.render(specUrl: '/docs.json'),
      ])
        ...RegExp(
          r'swagger-ui-dist@([\d.]+)/',
        ).allMatches(page).map((m) => m.group(1)!),
    };
    expect(versions, hasLength(1));
    final [major, minor, patch] = versions.single
        .split('.')
        .map(int.parse)
        .toList();
    // 5.32.0 reads OpenAPI 3.2; 5.32.15 lets "Try it out" send QUERY.
    expect(
      major > 5 || (major == 5 && (minor > 32 || (minor == 32 && patch >= 15))),
      isTrue,
      reason: 'swagger-ui-dist ${versions.single}',
    );
  });
}
