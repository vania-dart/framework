import 'package:test/test.dart';
import 'package:todos/features/todos/todo_repository.dart';

void main() {
  group('TodoRepository', () {
    late TodoRepository repo;

    setUp(() {
      repo = TodoRepository();
    });

    test('starts empty', () {
      expect(repo.all(), isEmpty);
    });

    test('create assigns incrementing ids', () {
      final a = repo.create('first');
      final b = repo.create('second');
      expect(a.id, 1);
      expect(b.id, 2);
      expect(repo.all(), hasLength(2));
    });

    test('find returns the todo by id', () {
      final created = repo.create('buy milk');
      expect(repo.find(created.id)!.title, 'buy milk');
    });

    test('find returns null for unknown id', () {
      expect(repo.find(999), isNull);
    });

    test('update changes only the given fields', () {
      final created = repo.create('draft');
      final updated = repo.update(created.id, completed: true);
      expect(updated!.title, 'draft');
      expect(updated.completed, isTrue);
    });

    test('update returns null for unknown id', () {
      expect(repo.update(999, title: 'x'), isNull);
    });

    test('delete removes the todo', () {
      final created = repo.create('temp');
      expect(repo.delete(created.id), isTrue);
      expect(repo.find(created.id), isNull);
    });

    test('delete returns false for unknown id', () {
      expect(repo.delete(999), isFalse);
    });
  });
}
