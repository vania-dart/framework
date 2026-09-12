---
sidebar_position: 1
---

# Walkthrough: Counter

**Sample:** `examples/counter` · **Needs:** nothing but Dart

This is the smallest useful Vania app. It keeps a single number in memory and exposes four routes to read and change it. There is no database and no external service, which makes it the right place to see how a request travels from the router to a controller and back out as JSON.

## Run it

```bash
cd examples/counter
dart pub get
dart run bin/server.dart
```

```bash
curl localhost:8000/api/counter                    # {"value":0}
curl -X POST localhost:8000/api/counter/increment  # {"value":1}
curl -X POST localhost:8000/api/counter/increment  # {"value":2}
curl -X POST localhost:8000/api/counter/reset       # {"value":0}
```

## The one idea: keep logic out of the controller

The counter itself is a plain Dart class. It knows nothing about HTTP.

```dart
// lib/app/counter.dart
class Counter {
  int _value = 0;

  int get value => _value;
  int increment([int by = 1]) => _value += by;
  int decrement([int by = 1]) => _value -= by;
  int reset() => _value = 0;
}

/// Single shared counter used by the controller.
final Counter counter = Counter();
```

Why bother separating it? Because now the behaviour can be tested directly, with no server:

```dart
// test/counter_test.dart (in spirit)
final c = Counter();
expect(c.increment(), 1);
expect(c.increment(), 2);
expect(c.reset(), 0);
```

This is the pattern that repeats across every sample in the repo. Keep the *rules* in a plain object; keep the *transport* (HTTP, WebSocket, gRPC) in a thin layer on top.

## The controller: translate, don't compute

```dart
// lib/app/http/controllers/counter_controller.dart
class CounterController extends Controller {
  Future<Response> show() async => Response.json({'value': counter.value});
  Future<Response> increment() async => Response.json({'value': counter.increment()});
  Future<Response> decrement() async => Response.json({'value': counter.decrement()});
  Future<Response> reset() async => Response.json({'value': counter.reset()});
}

final CounterController counterController = CounterController();
```

Each method does exactly one thing: call the counter and wrap the result in `Response.json`. There is no logic to get wrong here, which is the point.

## The routes

```dart
// lib/route/api_route.dart
class ApiRoute extends Route {
  @override
  String? get prefix => 'api';

  @override
  void register() {
    super.register();

    Router.get('/counter', counterController.show);
    Router.post('/counter/increment', counterController.increment);
    Router.post('/counter/decrement', counterController.decrement);
    Router.post('/counter/reset', counterController.reset);
  }
}
```

The `prefix` getter puts every route under `/api`. A route class groups related routes and registers them in one place.

## Wiring it together

Two more files connect the route to the running app.

A **service provider** boots the routes:

```dart
// lib/app/providers/route_service_provider.dart
class RouteServiceProvider extends ServiceProvider {
  @override
  Future<void> register() async {}

  @override
  Future<void> boot() async {
    ApiRoute().register();
  }
}
```

And the **config** lists the providers the app runs:

```dart
// lib/config/app.dart
Map<String, dynamic> config = {
  'name': env('APP_NAME', 'counter'),
  'url': env('APP_URL', 'http://localhost'),
  'providers': <ServiceProvider>[
    RouteServiceProvider(),
  ],
};
```

Finally `bin/server.dart` hands the config to the framework:

```dart
void main(List<String> arguments) async {
  await Application().initialize(config: config);
}
```

## What to take away

- A Vania app is: **config → providers → routes → controllers**.
- Controllers should translate requests and responses, not hold logic.
- Keeping the real behaviour in a plain class is what makes it testable without a server.

Next, see [Todos](todos.md), which takes this same skeleton and organises it by feature.
