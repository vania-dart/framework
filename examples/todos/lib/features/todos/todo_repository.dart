import 'package:todos/features/todos/todo.dart';

/// In-memory store for todos. Swap this class for a database-backed one
/// without touching the controller — that's the point of keeping the
/// feature's data access behind a repository.
class TodoRepository {
  final Map<int, Todo> _items = {};
  int _seq = 0;

  List<Todo> all() => _items.values.toList();

  Todo? find(int id) => _items[id];

  Todo create(String title) {
    final todo = Todo(id: ++_seq, title: title);
    _items[todo.id] = todo;
    return todo;
  }

  Todo? update(int id, {String? title, bool? completed}) {
    final existing = _items[id];
    if (existing == null) return null;
    final updated = existing.copyWith(title: title, completed: completed);
    _items[id] = updated;
    return updated;
  }

  bool delete(int id) => _items.remove(id) != null;
}

/// Shared repository instance for this feature.
final TodoRepository todoRepository = TodoRepository();
