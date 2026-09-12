# Counter Example

A minimal in-memory counter API built with the [Vania](../../packages/core)
framework. No database — just a shared `Counter` object behind four routes.

## Endpoints

| Method | Path                     | Description              |
|--------|--------------------------|--------------------------|
| GET    | `/api/counter`           | Current value            |
| POST   | `/api/counter/increment` | Add one, return value    |
| POST   | `/api/counter/decrement` | Subtract one, return value |
| POST   | `/api/counter/reset`     | Reset to zero            |

## Layout

```
lib/
  app/counter.dart                          # the counter logic (no HTTP)
  app/http/controllers/counter_controller.dart
  route/api_route.dart
  app/providers/route_service_provider.dart
  config/app.dart
bin/server.dart
test/counter_test.dart                       # unit tests for the counter
```

## Running

```bash
dart pub get
dart run bin/server.dart
```

## Tests

The counter logic lives in a plain `Counter` class, so it is tested directly
without a server:

```bash
dart test
```
