import 'package:mockito/annotations.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:vania/vania_framework.dart';

import 'pagination_extension_test.mocks.dart';

@GenerateMocks([QueryBuilder])
void main() {
  group('Pagination Extension', () {
    late MockQueryBuilder queryBuilder;
    setUp(() {
      queryBuilder = MockQueryBuilder();
      when(queryBuilder.count())
          .thenAnswer((_) async => 100); // Assuming 100 total items
      when(queryBuilder.limit(any)).thenReturn(queryBuilder);
      when(queryBuilder.offset(any)).thenReturn(queryBuilder);
      when(queryBuilder.get()).thenAnswer(
        (_) async => List.generate(
          15,
          (index) => {
            'data': List.generate(
                15, (index) => {'id': index, 'item': 'Item $index'}),
            'otherInfo': 'Additional info' // Include other keys if needed
          },
        ),
      );
    });

    test('paginate method provides correct pagination links', () async {
      // Assuming 'APP_URL' environment variable is set to 'http://example.com'
      final result = await queryBuilder.paginate(
          15, 2, 'http://example.com'); // Page 2, 15 items per page
      expect(result['total'], 100);
      expect(result['perPage'], 15);
      expect(result['page'], 2);
      expect(result['lastPage'], 7); // 100 items, 15 per page
      expect(result['nextLink'], 'http://example.com?page=3');
      expect(result['previousLink'], 'http://example.com?page=1');
      expect(result['data'].length, 15);
    });
    test('when we have no env or APP_URL should get ArgumentError', () async {
      // Assuming 'APP_URL' environment variable is set to 'http://example.com'
      expect(() => queryBuilder.paginate(15, 1, null),
          throwsA(isA<ArgumentError>()));
    });

    test('simplePaginate method handles boundaries correctly', () async {
      final firstPageResults = await queryBuilder.simplePaginate(15, 1);
      final lastPageResults =
          await queryBuilder.simplePaginate(15, 7); // last page calculation
      expect(firstPageResults['previous'], isNull);
      expect(firstPageResults['next'], 2);
      expect(lastPageResults['next'], isNull);
      expect(lastPageResults['previous'], 6);
    });
  });
}
