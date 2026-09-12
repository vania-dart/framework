import 'package:test/test.dart';
import 'package:vania_graphql/vania_graphql.dart';
import 'package:graphql_api/graphql/schema.dart';

void main() {
  late VaniaGraphQLExecutor executor;

  setUp(() {
    executor = VaniaGraphQLExecutor(
      schema: buildSchema(),
      config: const GraphQLConfig(),
    );
  });

  Future<Map<String, dynamic>> run(String query) async {
    final result = await executor.execute(VaniaGraphQLRequest(query: query));
    return result.payload!;
  }

  test('hello returns a greeting', () async {
    final data = await run('{ hello }');
    expect(data['data'], {'hello': 'Hello from Vania GraphQL'});
  });

  test('books returns every book', () async {
    final data = await run('{ books { id title } }');
    final books = (data['data'] as Map)['books'] as List;
    expect(books, hasLength(3));
    expect((books.first as Map)['title'], 'The Hobbit');
  });

  test('book(id:) returns a single book', () async {
    final data = await run('{ book(id: 2) { title author } }');
    expect((data['data'] as Map)['book'], {
      'title': 'Dune',
      'author': 'Frank Herbert',
    });
  });

  test('book with an unknown id resolves to null', () async {
    final data = await run('{ book(id: 999) { title } }');
    expect((data['data'] as Map)['book'], isNull);
  });

  test('a malformed query is reported as an error', () async {
    final data = await run('{ books { id ');
    expect(data['errors'], isNotNull);
  });
}
