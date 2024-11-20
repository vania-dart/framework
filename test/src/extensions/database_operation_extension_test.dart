import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:vania/vania_framework.dart';

import 'pagination_extension_test.mocks.dart';

void main() {
  group('Database Operations Tests', () {
    late MockQueryBuilder queryBuilder;
    late MockQueryBuilder whereQuery;
    setUp(() {
      queryBuilder = MockQueryBuilder();
      whereQuery = MockQueryBuilder();
    });

    test('create method returns a record on successful insert', () async {
      when(queryBuilder.insertGetId(any)).thenAnswer((_) async => 1);
      // Setup the chain for `where` method
      when(queryBuilder.where('id', '=', 1)).thenReturn(whereQuery);
      // Setup the return for `first`
      when(whereQuery.first())
          .thenAnswer((_) async => {'id': 1, 'name': 'Example'});

      final result = await queryBuilder.create({'name': 'Example'});
      expect(result, contains('id'));
      expect(result, contains('name'));
    });

    test('insertMany handles multiple records', () async {
      when(queryBuilder.insert(any)).thenAnswer((_) async => true);
      expect(
          await queryBuilder.insertMany([
            {'name': 'Example1'},
            {'name': 'Example2'}
          ]),
          isTrue);
    });
    test('create method throws on missing record', () async {
      when(queryBuilder.insert(any)).thenThrow(
          QueryException('SQL Error')); // Directly throw an exception

      expect(
          queryBuilder.insertMany([
            {'name': 'Example1'},
            {'name': 'Example2'}
          ]),
          throwsA(isA<HttpResponseException>()));
    });
  });
}
