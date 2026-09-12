import 'package:test/test.dart';
import 'package:vania/foundation.dart' show InvalidArgumentException;
import 'package:vania/src/database/query_builder/_query_builder_impl.dart';

/// Identifiers are interpolated into the statement — unlike values,
/// which are bound — so `orderBy`, `groupBy`, `having`, `table` and
/// `select` validate what they are given.
void main() {
  QueryBuilderImpl qb() => QueryBuilderImpl()..table('users');

  final invalid = throwsA(isA<InvalidArgumentException>());

  group('orderBy', () {
    test('accepts plain and qualified columns', () {
      expect(qb().orderBy('name').toSql(), contains('ORDER BY name ASC'));
      expect(
        qb().orderBy('users.created_at', 'desc').toSql(),
        contains('ORDER BY users.created_at DESC'),
      );
    });

    test('normalises the direction to upper case', () {
      expect(qb().orderBy('name', 'desc').toSql(), contains('name DESC'));
    });

    test('rejects an injected column', () {
      expect(() => qb().orderBy('id) --'), invalid);
      expect(() => qb().orderBy('id; DROP TABLE users'), invalid);
      expect(() => qb().orderBy('(SELECT password FROM users)'), invalid);
      expect(() => qb().orderBy('name, (SELECT 1)'), invalid);
    });

    test('rejects an injected direction', () {
      expect(() => qb().orderBy('name', 'ASC, (SELECT 1)'), invalid);
      expect(() => qb().orderBy('name', 'DESC; DROP TABLE users'), invalid);
    });

    test('orderByRaw is the explicit escape hatch', () {
      expect(
        qb().orderByRaw('FIELD(status, 1, 2, 3)').toSql(),
        contains('ORDER BY FIELD(status, 1, 2, 3)'),
      );
    });
  });

  group('groupBy / having', () {
    test('accepts plain columns', () {
      expect(qb().groupBy(['status']).toSql(), contains('GROUP BY status'));
    });

    test('rejects an injected group column', () {
      expect(() => qb().groupBy(['status)) --']), invalid);
    });

    test('groupByRaw is the explicit escape hatch', () {
      expect(
        qb().groupByRaw('DATE(created_at)').toSql(),
        contains('GROUP BY DATE(created_at)'),
      );
    });

    test('rejects an injected having column', () {
      expect(() => qb().having('total) OR 1=1 --', '>', 5), invalid);
    });

    test('rejects an invalid having operator', () {
      // HAVING accepts the same operator set as WHERE.
      expect(() => qb().having('total', 'OR 1=1 --', 5), invalid);
    });
  });

  group('table and select', () {
    test('accepts plain names and aliases', () {
      expect(
        (QueryBuilderImpl()..table('users', 'u')).toSql(),
        contains('users AS u'),
      );
    });

    test('rejects an injected table or alias', () {
      expect(() => QueryBuilderImpl().table('users; DROP TABLE x'), invalid);
      expect(() => QueryBuilderImpl().table('users', 'u) --'), invalid);
    });

    test('accepts wildcards, including qualified ones', () {
      expect(() => qb().select(['*']), returnsNormally);
      expect(() => qb().select(['users.*']), returnsNormally);
      expect(() => qb().select(['id', 'users.name']), returnsNormally);
    });

    test('rejects a wildcard that is not the last segment', () {
      expect(() => qb().select(['*.id']), invalid);
    });

    test('rejects an injected select column', () {
      expect(() => qb().select(['id, (SELECT password FROM users)']), invalid);
    });
  });

  group('inRandomOrder', () {
    test('accepts a numeric seed', () {
      expect(qb().inRandomOrder(42).toSql(), contains('RAND(42)'));
      expect(qb().inRandomOrder('7').toSql(), contains('RAND(7)'));
    });

    test('rejects a non-numeric seed', () {
      expect(() => qb().inRandomOrder('1); DROP TABLE users --'), invalid);
    });
  });

  group('selectRaw parameter naming', () {
    test('does not collide with where-clause bindings', () {
      // selectRaw draws its placeholder names from the same counter as
      // the where clauses, so neither can overwrite the other.
      final q = QueryBuilderImpl()..table('users');
      q.where('status', '=', 'active');
      q.selectRaw('(SELECT COUNT(*) FROM posts WHERE views > ?) AS c', [10]);
      q.where('age', '>', 18);

      final bindings = q.getBindings();
      expect(
        bindings.length,
        equals(3),
        reason: 'a duplicate placeholder name would drop a binding',
      );
      expect(bindings.values, containsAll(<dynamic>['active', 10, 18]));

      final placeholders = RegExp(
        r':(p\d+)',
      ).allMatches(q.toSql()).map((m) => m.group(1)!).toSet();
      expect(placeholders.difference(bindings.keys.toSet()), isEmpty);
    });
  });
}
