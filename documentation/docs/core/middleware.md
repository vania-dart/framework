---
sidebar_position: 5
---

# Middleware

Middleware runs before (and optionally after) your controller. Use it for authentication checks, rate limiting, logging, or any cross-cutting concern that shouldn't clutter the controller.

There are two ways to write one, depending on whether you need to act *before* the controller or *around* it.

## The common case: `handle`

Override `handle(Request req)` when the middleware only inspects or augments the request. To reject the request, **throw** — an exception aborts the chain and the framework turns it into the right HTTP response. If `handle` returns normally, the chain continues.

```dart
import 'package:vania/vania.dart' show Unauthenticated;
import 'package:vania/http/middleware.dart';
import 'package:vania/http/request.dart';

class RequireApiKey extends Middleware {
  @override
  Future<void> handle(Request req) async {
    if (req.header('x-api-key') != expectedKey) {
      throw Unauthenticated(message: 'Bad or missing API key');
    }
    // Pass data to the controller by merging it into the request:
    req.merge({'tenant': tenantFor(req)});
  }
}
```

There is no `next()` to call here and no `abort()` helper — returning continues the chain, throwing stops it. Throw one of the framework's exceptions (`Unauthenticated`, `Forbidden`, `HttpException`, …) to control the status code. See [Error Handling](error-handling.md).

## Acting after the controller: `process`

Override `process(Request req, Next next)` when you need to do something *after* the rest of the chain runs — timing, logging, or adding a header that depends on the response — or when you want to skip the chain entirely. Call `await next()` to run the remaining middleware and the controller.

```dart
class Timing extends Middleware {
  @override
  Future<void> process(Request req, Next next) async {
    final started = DateTime.now();
    await next();                              // run the rest of the chain
    final ms = DateTime.now().difference(started).inMilliseconds;
    req.response.headers.add('X-Duration-Ms', '$ms');
  }
}
```

Not calling `next()` stops the chain: no later middleware runs, the controller is never invoked, and your middleware becomes responsible for the response. Override **either** `handle` or `process`, not both — if you define `process`, `handle` is ignored.

## Attaching middleware to routes

Attach per-route or per-group with `.middleware([...])`:

```dart
// Single route
Router.post('/upload', uploadController.store)
    .middleware([Authenticate(), FileSizeLimit()]);

// A whole group
Router.group(() {
  Router.get('/users', userController.index);
  Router.get('/settings', settingsController.index);
}, prefix: 'admin', middleware: [AdminMiddleware()]);
```

Group middleware runs before route middleware, and each list runs in order.

## Built-in middleware

### Throttle (rate limiting)

```dart
import 'package:vania/http/middleware.dart';

Router.post('/login', authController.login)
    .middleware([Throttle(maxRequests: 5, perMinutes: 1)]);
```

Five requests per minute per client; excess requests get `429 Too Many Requests`.

### Security headers

`SecurityHeaders` middleware (exported from `package:vania/http/middleware.dart`) adds common hardening headers to responses. Attach it to a group to cover many routes at once.

### Authentication

The `Authenticate` middleware from `vania_auth` validates bearer tokens and loads the user:

```dart
import 'package:vania_auth/vania_auth.dart';

Router.get('/profile', userController.profile)
    .middleware([Authenticate()]);
```

Inside the handler the user is available as `req.user`. See [Authentication](../packages/auth.md).

## WebSocket middleware

WebSocket upgrades use a separate base, `WebSocketMiddleware`, whose `handle` receives the raw `HttpRequest`. Reject by writing a response and closing the connection:

```dart
class WsAuth extends WebSocketMiddleware {
  @override
  Future handle(HttpRequest req) async {
    final token = req.uri.queryParameters['token'];
    if (token == null || !isValid(token)) {
      req.response.statusCode = 401;
      await req.response.close();
    }
  }
}
```

Attach it when registering the socket route:

```dart
Router.websocket('/ws', eventHandler, middleware: [WsAuth()]);
```

## Execution order

1. Group middleware (outer groups first, then inner)
2. Route middleware, in the order listed
3. The controller action

A middleware that throws, or that overrides `process` and doesn't call `next()`, stops the chain there.

## Generate a middleware

```bash
vania make:middleware rate_limit
```

This creates `lib/app/http/middleware/rate_limit_middleware.dart` with a skeleton you can fill in.
