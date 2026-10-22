---
sidebar_position: 1
---

# Routing

Routes map incoming HTTP requests to controller methods or inline closures. Vania's router uses a static, fluent API — you register all routes at boot time, and the framework matches them against each incoming request.

## Defining Routes

Routes are defined inside classes that extend `Route`. Override the `prefix` getter to set a base path for the whole file, call `super.register()` first (it applies that prefix), then add your routes:

```dart
import 'package:vania/route.dart';
import 'package:my_app/app/http/controllers/user_controller.dart';

class ApiRoute extends Route {
  @override
  String? get prefix => 'api';

  @override
  void register() {
    super.register();

    Router.get('/users', userController.index);
    Router.post('/users', userController.store);
    Router.get('/users/{id}', userController.show).whereInt('id');
    Router.put('/users/{id}', userController.update).whereInt('id');
    Router.delete('/users/{id}', userController.destroy).whereInt('id');
  }
}
```

Overriding `prefix` is the idiomatic way to prefix a file. `super.register()` calls `Router.basePrefix(prefix)` for you, so every route below is registered under `/api`.

## Available HTTP Methods

```dart
Router.get(path, action);
Router.post(path, action);
Router.put(path, action);
Router.patch(path, action);
Router.delete(path, action);
Router.options(path, action);
Router.query(path, action);    // HTTP QUERY, see below
Router.any(path, action);      // matches all methods
```

Additional methods for specialized protocols: `Router.purge`, `Router.copy`, `Router.link`, `Router.unlink`, `Router.lock`, `Router.unlock`, `Router.propfind`.

### QUERY Routes

`QUERY` ([RFC 10008](https://www.rfc-editor.org/rfc/rfc10008)) is a read like `GET`, safe and idempotent, that carries the query in the request content as `POST` does. Use it when a query is too large or too complex for a URL, or too sensitive to leave in one: URLs end up in logs and browser history, request content generally does not.

```dart
Router.query('/contacts', contactController.search)
    .acceptQuery(['application/json', 'application/x-www-form-urlencoded']);
```

A JSON or form-encoded query reaches the action as ordinary input, so `req.input('surname')` and `req.validate(...)` work as they do for a `POST`. Any other media type, such as SQL or GraphQL, is in `req.rawBody`:

```dart
Router.query('/reports', (Request req) {
  final sql = utf8.decode(req.rawBody); // Content-Type: application/sql
  // ...
});
```

The framework applies the RFC's rules for you:

- A `QUERY` without a `Content-Type`, or whose content does not parse as that type, is answered with **400**.
- With `acceptQuery`, a request of any other media type gets **415**, and responses carry an `Accept-Query` header listing the accepted types. `type/*` and `*/*` are allowed.
- An `OPTIONS` request to the path answers with an `Allow` header naming its methods (`GET, QUERY, OPTIONS`) and, when set, `Accept-Query`. That is how a client finds out a resource supports `QUERY`.
- `QUERY` is safe, so CSRF protection does not apply to it, and `Response.fromPath` honours `Range` for it as for `GET`.

Browsers cannot send `QUERY` from an HTML form, only with `fetch()`. A cross-origin `QUERY` is preflighted, so add `QUERY` to the CORS `methods` (see [Configuration](../getting-started/configuration.md#cors)).

## Route Actions

A route action can be a controller method or an inline closure:

```dart
// Controller method
Router.get('/posts', postController.index);

// Inline closure returning Response
Router.get('/health', () => Response.json({'status': 'ok'}));

// Closure with Request parameter
Router.post('/echo', (Request req) {
  return Response.json(req.all());
});
```

## Route Parameters

Use curly braces to define dynamic segments:

```dart
Router.get('/users/{id}', userController.show);
Router.get('/posts/{postId}/comments/{commentId}', commentController.show);
```

Parameters are passed as positional arguments to the action, decoded: a request for `/posts/%D8%B3%D9%84%D8%A7%D9%85` gives `سلام`. Routes may be written in any script — `Router.get('/مقالات/{id}', ...)` matches the encoded request a browser sends for it. An unconstrained parameter is converted from its text: `42` arrives as an `int`, `4.2` as a `double`, `true` or `false` as a `bool`, and anything else as a `String`. To receive digits as a `String` (a slug such as `2024`, say), constrain it with `whereString`.

### Parameter Type Constraints

Constrain parameter types to reject non-matching requests early. A constrained parameter reaches the action as that type, and a value that does not fit is a 404:

```dart
Router.get('/users/{id}', userController.show)
    .whereInt('id');

Router.get('/price/{amount}', handler)
    .whereDouble('amount');

Router.get('/active/{flag}', handler)
    .whereBool('flag');

Router.get('/archive/{year}', handler)
    .whereString('year'); // "2024" stays a String

// Custom regex constraint
Router.get('/slug/{slug}', handler)
    .where('slug', r'[a-z0-9-]+');
```

A `where` pattern has to match the whole segment: `r'\d+'` takes `123` but not `abc123`.

## Route Groups

Group related routes to share a prefix, middleware, or domain:

```dart
Router.group(() {
  Router.get('/profile', userController.profile);
  Router.put('/profile', userController.updateProfile);
  Router.get('/settings', userController.settings);
}, prefix: 'account', middleware: [AuthenticateMiddleware()]);
```

Groups can be nested. Prefixes concatenate, and middleware stacks merge:

```dart
Router.group(() {
  Router.get('/stats', adminController.stats);

  Router.group(() {
    Router.get('/', userController.index);
    Router.delete('/{id}', userController.destroy);
  }, prefix: 'users');
}, prefix: 'admin', middleware: [AdminMiddleware()]);
// Produces: /admin/stats, /admin/users, /admin/users/{id}
```

## Base Prefix

Set a prefix that applies to all subsequent route registrations in a route file:

```dart
Router.basePrefix('api/v1');

Router.get('/users', handler);   // matches /api/v1/users
Router.get('/posts', handler);   // matches /api/v1/posts
```

## Resource Routes

Register all seven RESTful routes for a resource in a single call:

```dart
Router.resource('/posts', postController);
```

This registers:

| Method | Path | Action |
|--------|------|--------|
| GET | /posts | `index` |
| GET | /posts/create | `create` |
| POST | /posts | `store` |
| GET | `/posts/{id}` | `show` |
| GET | `/posts/{id}/edit` | `edit` |
| PUT | `/posts/{id}` | `update` |
| DELETE | `/posts/{id}` | `destroy` |

## Middleware

Attach middleware to individual routes or groups:

```dart
// Single route
Router.get('/dashboard', dashboardController.index)
    .middleware([AuthenticateMiddleware()]);

// Multiple middleware
Router.post('/admin/settings', adminController.updateSettings)
    .middleware([AuthenticateMiddleware(), AdminMiddleware()]);
```

See [Middleware](middleware.md) for writing custom middleware.

## Named Routes

Give a route a name for URL generation:

```dart
Router.get('/users/{id}', userController.show)
    .name('user.show');

// Later, generate the URL:
String url = Router.url('user.show', {'id': 42});
// => /users/42
```

## Domain Routing

Bind routes to a specific domain or subdomain:

```dart
Router.group(() {
  Router.get('/dashboard', adminController.dashboard);
}, domain: 'admin.example.com');
```

## WebSocket Routes

Register a WebSocket endpoint with event-based handlers:

```dart
Router.websocket('/ws', (WebSocketEvent event) {
  event.on('message', (WebSocketClient client, dynamic data) {
    client.toRoom('chat', 'room_1', data);
  });

  event.on('disconnect', (WebSocketClient client, dynamic data) {
    print('Client disconnected');
  });
});
```

## Route Registration

Routes are registered through a service provider. Register them in `boot()` (which runs after every provider's `register()`), so any bindings your routes depend on already exist:

```dart
class RouteServiceProvider extends ServiceProvider {
  @override
  Future<void> register() async {}

  @override
  Future<void> boot() async {
    ApiRoute().register();
    // ...register any other route classes here
  }
}
```

Add this provider to your `config/app.dart` providers list. See [Service Providers](service-providers.md) for the `register` / `boot` lifecycle.
