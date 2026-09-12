library;

import 'package:test/test.dart';
import 'package:vania/database.dart';
import 'package:vania/foundation.dart' show InvalidArgumentException;

class FakeConnection implements DatabaseConnection {
  final Map<String, List<Map<String, dynamic>>> tables;
  final List<String> queries = [];

  FakeConnection(this.tables);

  String _tableOf(String query) {
    final match = RegExp(
      r'FROM\s+(\w+)',
      caseSensitive: false,
    ).firstMatch(query);
    return match?.group(1) ?? '';
  }

  @override
  Future<List<Map<String, dynamic>>> select(
    String query, [
    Map<String, dynamic> bindings = const {},
  ]) async {
    queries.add(query);
    return (tables[_tableOf(query)] ?? [])
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<void> connect() async {}
  @override
  Future<void> close() async {}
  @override
  Future<dynamic> insert(String q, [Map<String, dynamic> b = const {}]) async =>
      1;
  @override
  Future<bool> execute(String q, [Map<String, dynamic> b = const {}]) async =>
      true;
  @override
  Future<T> transaction<T>(Future<T> Function() action) => action();
}

class Post extends Model {
  Post() {
    super.tableName = 'posts';
  }

  @override
  List<String> get hidden => ['draft_notes'];
}

class Author extends Model {
  Author() {
    super.tableName = 'authors';
  }

  @override
  List<String> get hidden => ['password', 'id'];

  @override
  bool get timestamps => false;

  @override
  void registerRelations() {
    hasMany('posts', Post(), foreignKey: 'author_id');
  }
}

class BlogAuthor extends Model {
  @override
  bool get timestamps => false;

  @override
  void registerRelations() {
    hasMany('posts', Post());
  }
}

void main() {
  late FakeConnection connection;

  setUp(() {
    connection = FakeConnection({
      'authors': [
        {'id': 1, 'name': 'Ada', 'password': 'secret'},
      ],
      'posts': [
        {
          'id': 10,
          'author_id': 1,
          'title': 'Hello',
          'draft_notes': 'unpublished',
        },
      ],
    });
    ConnectionManager().connectionMap['mysql'] = connection;
    ConnectionManager().defaultConnection = 'mysql';
  });

  tearDown(() {
    ConnectionManager().connectionMap.clear();
    ConnectionManager().defaultConnection = null;
  });

  group('Model.hidden', () {
    test('get() strips hidden columns', () async {
      final rows = await Author().get();
      expect(rows.single.containsKey('password'), isFalse);
      expect(rows.single['name'], 'Ada');
    });

    test('first() strips hidden columns', () async {
      final row = await Author().first();
      expect(row!.containsKey('password'), isFalse);
      expect(row['name'], 'Ada');
    });

    test('find() strips hidden columns', () async {
      final row = await Author().find(1);
      expect(row!.containsKey('password'), isFalse);
      expect(row['name'], 'Ada');
    });

    test(
      'toJson() strips hidden columns and emits no relation objects',
      () async {
        final author = Author();
        await author.find(1);
        final json = author.toJson();
        expect(json.containsKey('password'), isFalse);
        expect(json['name'], 'Ada');
        expect(json.values.every((v) => v is! Relation), isTrue);
      },
    );
  });

  group('Model.hidden — single-column reads', () {
    test('value() rejects a hidden column', () {
      expect(
        () => Author().value('password'),
        throwsA(isA<InvalidArgumentException>()),
      );
    });

    test('pluck() rejects a hidden column', () {
      expect(
        () => Author().pluck('password'),
        throwsA(isA<InvalidArgumentException>()),
      );
    });

    test('pluck() rejects a hidden key column', () {
      expect(
        () => Author().pluck('name', 'id'),
        throwsA(isA<InvalidArgumentException>()),
      );
    });

    test('pluck() still reads visible columns, keyed', () async {
      final result = await Post().pluck('title', 'id');
      expect(result, {10: 'Hello'});
    });
  });

  group('QueryBuilder.resetQuery', () {
    test('drops clauses but keeps the table and connection', () {
      final qb = QueryBuilderImpl().table('users').where('active', '=', 1)
        ..orderBy('id')
        ..limit(5);
      qb.toSql();

      qb.resetQuery();

      expect(qb.toSql(), 'SELECT * FROM users');
      expect(qb.getBindings(), isEmpty);
    });

    test('a reused builder does not stack WHERE clauses', () {
      final qb = QueryBuilderImpl().table('users');
      final first = qb.where('active', '=', 1).toSql();
      qb.resetQuery();
      final second = qb.where('active', '=', 1).toSql();
      expect(second, first);
    });
  });

  group('Model relations', () {
    test(
      'a hidden column can still be the key a relation matches on',
      () async {
        final rows = await Author().include('posts').get();
        final posts = rows.single['posts'] as List;
        expect(
          posts,
          hasLength(1),
          reason: 'hidden must be applied after relations are resolved',
        );
        expect(rows.single.containsKey('id'), isFalse);
      },
    );

    test("the related model's own hidden columns are stripped", () async {
      final rows = await Author().include('posts').get();
      final post = (rows.single['posts'] as List).single as Map;
      expect(post.containsKey('draft_notes'), isFalse);
      expect(post['title'], 'Hello');
    });

    test('rows with a null key are not queried for', () async {
      connection.tables['authors'] = [
        {'id': null, 'name': 'Orphan', 'password': 'secret'},
      ];
      final rows = await Author().include('posts').get();
      expect(rows.single['posts'], isEmpty);
      expect(
        connection.queries.where((q) => q.contains('FROM posts')),
        isEmpty,
        reason: 'no non-null keys means there is nothing to load',
      );
    });

    test(
      'a second eager load does not inherit the first one\'s clauses',
      () async {
        final author = Author();
        await author.include('posts').get();
        final firstPostsQuery = connection.queries.firstWhere(
          (q) => q.contains('FROM posts'),
        );

        connection.queries.clear();
        await author.include('posts').get();
        final secondPostsQuery = connection.queries.firstWhere(
          (q) => q.contains('FROM posts'),
        );

        expect(
          secondPostsQuery,
          firstPostsQuery,
          reason: 'the related model is shared and must start clean',
        );
        expect('WHERE'.allMatches(secondPostsQuery), hasLength(1));
      },
    );

    test(
      'the default foreign key is snake_cased from the parent type',
      () async {
        connection.tables['blog_authors'] = [
          {'id': 1, 'name': 'Ada'},
        ];
        await BlogAuthor().include('posts').get();

        final postsQuery = connection.queries.firstWhere(
          (q) => q.contains('FROM posts'),
        );
        expect(postsQuery, contains('blog_author_id'));
      },
    );
  });
}
