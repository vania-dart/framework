# Todos Example (feature-based & modular)

A small todos API built with the [Vania](../../packages/core) framework,
organized by **feature** instead of by technical layer. Everything a feature
needs lives in its own folder, and features are plugged in through a single
`modules` list.

## Structure

```
lib/
  features/
    todos/                 # ← the whole feature in one folder
      todo.dart            #   entity
      todo_repository.dart #   in-memory data access (swap for a DB later)
      todo_controller.dart #   HTTP handlers
      todos_route.dart     #   the feature's own routes
  modules.dart             # the list of feature routes the app is composed of
  app/providers/route_service_provider.dart  # registers every module
  config/app.dart
bin/server.dart
test/todo_repository_test.dart
```

### Why this is "modular"

- A feature owns its entity, repository, controller, and routes together —
  you read or change a feature without hopping across `controllers/`,
  `models/`, `routes/` folders.
- Adding a feature is: create `lib/features/<name>/`, expose a `Route`, and
  add it to `modules.dart`. No other file changes.
- Data access sits behind `TodoRepository`, so the in-memory store can be
  replaced with a database-backed one without touching the controller.

## Endpoints

| Method | Path              | Description        |
|--------|-------------------|--------------------|
| GET    | `/api/todos`      | List todos         |
| POST   | `/api/todos`      | Create a todo      |
| GET    | `/api/todos/{id}` | Show one todo      |
| PUT    | `/api/todos/{id}` | Update a todo      |
| DELETE | `/api/todos/{id}` | Delete a todo      |

## Running

```bash
dart pub get
dart run bin/server.dart
```

## Tests

```bash
dart test
```
