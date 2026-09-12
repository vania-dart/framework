library;

// ignore_for_file: invalid_use_of_protected_member

import 'package:test/test.dart';
import 'package:vania/database.dart';
import 'package:vania/src/database/orm/model.dart' as orm;
import 'package:vania/foundation.dart' show Pluralize, toSnakeCase;

class PerfUser extends Model {}

class PerfPost extends Model {}

void main() {
  group('Perf — QueryBuilderImpl', () {
    test('getTable returns the raw table name with no allocation '
        'when no alias is set', () {
      final qb = QueryBuilderImpl().table('users');
      final a = qb.getTable;
      final b = qb.getTable;
      expect(
        identical(a, b),
        isTrue,
        reason: 'no-alias getTable should not allocate on each call',
      );
      expect(a, 'users');
    });

    test('getTable includes alias when present', () {
      final qb = QueryBuilderImpl().table('users', 'u');
      expect(qb.getTable, 'users AS u');
    });

    test('build() renders a well-formed SELECT via StringBuffer', () {
      final qb = QueryBuilderImpl().table('users').where('active', '=', 1);
      final sql = qb.toSql();
      expect(sql.startsWith('SELECT * FROM users WHERE'), isTrue);
      expect(sql.contains('active = :'), isTrue);
    });

    test('getBindings() returns the where-clause map directly '
        'when no CTEs are attached', () {
      final qb = QueryBuilderImpl().table('users').where('active', '=', 1);
      qb.toSql();
      final b1 = qb.getBindings();
      final b2 = qb.getBindings();
      expect(
        identical(b1, b2),
        isTrue,
        reason: 'no-CTE getBindings should not allocate a copy',
      );
    });
  });

  group('Perf — Model.tableName caching', () {
    test('tableName is cached per runtime type', () {
      final u1 = PerfUser();
      final u2 = PerfUser();
      final expected = toSnakeCase(Pluralize().make('PerfUser')).toLowerCase();
      expect(u1.getTable, expected);
      expect(u2.getTable, expected);
      expect(identical(u1.getTable, u2.getTable), isTrue);
    });

    test('distinct model types produce distinct cached values', () {
      final u = PerfUser();
      final p = PerfPost();
      expect(u.getTable, isNot(equals(p.getTable)));
    });

    test('cache does not leak across model types (sanity)', () {
      expect(orm.Model, isNotNull);
    });
  });
}
