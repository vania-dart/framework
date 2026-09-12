---
sidebar_position: 2
---

# Walkthrough: Todos (modular, feature-based)

**Sample:** `examples/todos` · **Needs:** nothing but Dart

The counter sample organised code by technical layer — a `controllers/` folder, a `route/` folder, and so on. That works until an app grows, at which point a single change means hopping between four folders. This sample shows the alternative: organise by **feature**. Everything the "todos" feature needs lives in one folder, and features plug into the app through a single list.

It also introduces the **repository** pattern — putting data access behind an interface so you can swap an in-memory store for a database later without touching the controller.

## Run it

```bash
cd examples/todos
dart pub get
dart run bin/server.dart
```

```bash
curl localhost:8000/api/todos                                   # {"data":[]}
curl -X POST localhost:8000/api/todos -d '{"title":"Buy milk"}' # {"id":1,...}
curl localhost:8000/api/todos/1
```

## The layout

```
lib/
  features/
    todos/                 # ← the whole feature in one folder
      todo.dart            #   entity
      todo_repository.dart #   data access
      todo_controller.dart #   HTTP handlers
      todos_route.dart     #   the feature's routes
  modules.dart             # the list of features the app is composed of
```

The rule is simple: to add a feature, create `lib/features/<name>/`, give it a `Route`, and add that route to `modules.dart`. No other file changes.

## The entity

A plain, immutable data holder. `copyWith` makes updates produce a new value instead of mutating in place.

```dart
// lib/features/todos/todo.dart
class Todo {
  final int id;
  final String title;
  final bool completed;

  const Todo({required this.id, required this.title, this.completed = false});

  Todo copyWith({String? title, bool? completed}) => Todo(
        id: id,
        title: title ?? this.title,
        completed: completed ?? this.completed,
      );

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'completed': completed};
}
```

## The repository: the seam you will thank yourself for

```dart
// lib/features/todos/todo_repository.dart
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

final TodoRepository todoRepository = TodoRepository();
```

Right now it stores todos in a `Map`. The controller never sees that. The day you want a real database, you write a `DatabaseTodoRepository` with the same methods and swap the one line that constructs it — nothing in the controller or routes changes. That is why the tests can exercise the repository directly, with no database.

## The controller: HTTP in, HTTP out

```dart
// lib/features/todos/todo_controller.dart
class TodoController extends Controller {
  Future<Response> index(Request req) async {
    return Response.json({'data': todoRepository.all().map((t) => t.toJson()).toList()});
  }

  Future<Response> show(Request req, int id) async {
    final todo = todoRepository.find(id);
    if (todo == null) return Response.json({'message': 'Not found'}, 404);
    return Response.json(todo.toJson());
  }

  Future<Response> store(Request req) async {
    await req.validate({'title': 'required|string|max_length:255'});
    final todo = todoRepository.create(req.input('title') as String);
    return Response.json(todo.toJson(), 201);
  }

  Future<Response> update(Request req, int id) async {
    final todo = todoRepository.update(
      id,
      title: req.input('title') as String?,
      completed: req.input('completed') as bool?,
    );
    if (todo == null) return Response.json({'message': 'Not found'}, 404);
    return Response.json(todo.toJson());
  }

  Future<Response> destroy(Request req, int id) async {
    if (!todoRepository.delete(id)) return Response.json({'message': 'Not found'}, 404);
    return Response.json({'message': 'Deleted'});
  }
}
```

Two things worth noticing:

- `req.validate({'title': 'required|string|max_length:255'})` rejects bad input before you touch the repository. If validation fails, Vania returns a `422` with the errors — you never reach the next line.
- The `id` parameter is passed straight into the method. That comes from the route.

## The routes

```dart
// lib/features/todos/todos_route.dart
class TodosRoute extends Route {
  @override
  String? get prefix => 'api';

  @override
  void register() {
    super.register();

    Router.get('/todos', todoController.index);
    Router.post('/todos', todoController.store);
    Router.get('/todos/{id}', todoController.show).whereInt('id');
    Router.put('/todos/{id}', todoController.update).whereInt('id');
    Router.delete('/todos/{id}', todoController.destroy).whereInt('id');
  }
}
```

`.whereInt('id')` constrains the `{id}` segment to integers, so `/api/todos/abc` never reaches the controller — it simply doesn't match the route.

## Composing the app from features

```dart
// lib/modules.dart
final List<Route> modules = [
  TodosRoute(),
];
```

The route provider just loops over that list:

```dart
// lib/app/providers/route_service_provider.dart
Future<void> boot() async {
  for (final module in modules) {
    module.register();
  }
}
```

Adding a `comments` feature is now a two-step change: create `lib/features/comments/` with a `CommentsRoute`, and add `CommentsRoute()` to `modules`. Nothing else in the app is aware of it.

## What to take away

- **Feature folders** keep everything about one concern together; **modules.dart** is the single place features are plugged in.
- A **repository** hides data access so the controller depends on behaviour, not storage — which is what lets you start in memory and move to a database later.
- **Validate first**, then act.

For a stricter take on this layering, read the [DDD Wallet](ddd-wallet.md) walkthrough next.
