import 'package:test/test.dart';
import 'package:vania_graphql/src/executor/graphql_depth_limiter.dart';

/// Query nesting depth. A schema with a cycle in it lets a few hundred
/// bytes fan out into unbounded resolver work, so depth is bounded.
void main() {
  int? depth(String q) => GraphQLDepthLimiter.depthOf(q);

  group('depth measurement', () {
    test('a flat query is depth 1', () {
      expect(depth('{ hello }'), equals(1));
    });

    test('each level of nesting counts once', () {
      expect(depth('{ user { name } }'), equals(2));
      expect(depth('{ user { posts { title } } }'), equals(3));
      expect(depth('{ a { b { c { d { e } } } } }'), equals(5));
    });

    test('the deepest branch wins, not the last one', () {
      expect(depth('{ a { b { c } } z }'), equals(3));
      expect(depth('{ z a { b { c } } }'), equals(3));
    });

    test('named operations are measured the same as anonymous ones', () {
      expect(depth('query Q { user { posts { title } } }'), equals(3));
    });

    test('the deepest operation in a multi-operation document wins', () {
      expect(depth('query A { x } query B { a { b { c } } }'), equals(3));
    });
  });

  group('depth cannot be hidden', () {
    test('fragments are expanded, not skipped', () {
      const query = '''
        query { user { ...deep } }
        fragment deep on User { posts { comments { author { name } } } }
      ''';
      // user(1) + posts(2) + comments(3) + author(4) + name(5)
      expect(depth(query), equals(5));
    });

    test('nested fragment spreads are followed all the way down', () {
      const query = '''
        query { a { ...f1 } }
        fragment f1 on A { b { ...f2 } }
        fragment f2 on B { c { d } }
      ''';
      // a → b → c → d
      expect(depth(query), equals(4));
    });

    test('inline fragments add a type condition, not a level', () {
      expect(
        depth('{ user { ... on Admin { name } } }'),
        equals(2),
        reason: 'an inline fragment is not a nesting level',
      );
    });
  });

  group('hostile input', () {
    test('a cyclic fragment spread terminates instead of hanging', () {
      const query = '''
        query { a { ...loop } }
        fragment loop on A { b { ...loop } }
      ''';
      // The point is that this returns at all.
      expect(depth(query), isNotNull);
    });

    test('an unknown fragment does not throw', () {
      expect(depth('query { a { ...missing } }'), isNotNull);
    });

    test('unparseable input yields no opinion rather than an error', () {
      expect(depth('this is not graphql {{{'), anyOf(isNull, isA<int>()));
      expect(depth(''), anyOf(isNull, isA<int>()));
    });

    test('a deeply nested attack query is measured as deep', () {
      // Build 50 levels of `a { a { … } }`.
      final buf = StringBuffer('{ ');
      for (var i = 0; i < 50; i++) {
        buf.write('a { ');
      }
      buf.write('id');
      for (var i = 0; i < 50; i++) {
        buf.write(' }');
      }
      buf.write(' }');

      expect(depth(buf.toString()), equals(51));
    });
  });
}
