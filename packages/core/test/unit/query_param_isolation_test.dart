import 'package:test/test.dart';
import 'package:vania/database.dart' show QueryBuilder;
import 'package:vania/src/database/query_builder/_query_builder_impl.dart';

void main() {
  Set<String> placeholders(String sql) =>
      RegExp(r':(p\d+)').allMatches(sql).map((m) => m.group(1)!).toSet();

  group('parameter counter isolation', () {
    test('two builders built in lockstep keep their own bindings', () {
      final a = QueryBuilderImpl()..table('users');
      final b = QueryBuilderImpl()..table('orders');

      a.where('name', '=', 'ali');
      b.where('status', '=', 'paid');
      a.where('city', '=', 'tehran');
      b.where('total', '>', 100);
      a.where('active', '=', true);

      final aSql = a.toSql();
      final bSql = b.toSql();
      final aBindings = a.getBindings();
      final bBindings = b.getBindings();

      expect(
        placeholders(aSql).difference(aBindings.keys.toSet()),
        isEmpty,
        reason: 'builder A referenced a parameter it never bound: $aSql',
      );
      expect(
        placeholders(bSql).difference(bBindings.keys.toSet()),
        isEmpty,
        reason: 'builder B referenced a parameter it never bound: $bSql',
      );

      expect(aBindings.values, containsAll(<dynamic>['ali', 'tehran', true]));
      expect(bBindings.values, containsAll(<dynamic>['paid', 100]));
      expect(aBindings.values, isNot(contains('paid')));
      expect(bBindings.values, isNot(contains('ali')));
    });

    test('reading bindings mid-build does not rewind the counter', () {
      final q = QueryBuilderImpl()..table('users');
      q.where('a', '=', 1);
      q.where('b', '=', 2);

      final mid = Map<String, dynamic>.from(q.getBindings());
      expect(mid.length, equals(2));

      q.where('c', '=', 3);

      final sql = q.toSql();
      final bindings = q.getBindings();

      expect(
        bindings.length,
        equals(3),
        reason: 'each clause must keep its own binding',
      );
      expect(bindings.values, containsAll(<dynamic>[1, 2, 3]));
      expect(placeholders(sql).length, equals(3));
      expect(placeholders(sql).difference(bindings.keys.toSet()), isEmpty);
    });

    test('another builder reading bindings cannot rewind ours', () {
      final mine = QueryBuilderImpl()..table('users');
      mine.where('a', '=', 1);
      mine.where('b', '=', 2);

      (QueryBuilderImpl()..table('logs')).where('x', '=', 9).getBindings();

      mine.where('c', '=', 3);

      final bindings = mine.getBindings();
      expect(bindings.length, equals(3));
      expect(bindings.values, containsAll(<dynamic>[1, 2, 3]));
      expect(
        placeholders(mine.toSql()).difference(bindings.keys.toSet()),
        isEmpty,
      );
    });

    test('nested subquery params do not collide with the parent', () {
      final q = QueryBuilderImpl()..table('users');
      q.where('a', '=', 1);
      q.orWhere((QueryBuilder nested) {
        nested.where('b', '=', 2);
        return nested.where('c', '=', 3);
      });
      q.where('d', '=', 4);

      final sql = q.toSql();
      final bindings = q.getBindings();

      expect(
        bindings.length,
        equals(4),
        reason: 'the parent must not reuse a subquery placeholder name',
      );
      expect(bindings.values, containsAll(<dynamic>[1, 2, 3, 4]));
      expect(placeholders(sql).length, equals(4));
      expect(placeholders(sql).difference(bindings.keys.toSet()), isEmpty);
    });

    test('a fresh builder starts numbering from p1', () {
      (QueryBuilderImpl()..table('noise'))
        ..where('x', '=', 1)
        ..where('y', '=', 2)
        ..where('z', '=', 3);

      final fresh = QueryBuilderImpl()..table('users');
      fresh.where('only', '=', 'one');

      expect(fresh.getBindings().keys, equals(<String>{'p1'}));
    });
  });
}
