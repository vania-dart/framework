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

The response is written only once every middleware has finished, so the header above still reaches the client. An exception from the controller or a later middleware comes back out of `await next()`: a `process` middleware can catch it to log or measure it, and should rethrow it so it is still answered.

Not calling `next()` stops the chain: no later middleware runs, the controller is never invoked, and your middleware becomes responsible for the response. Calling it twice is an error, since it would run the controller twice. Override **either** `handle` or `process`, not both — if you define `process`, `handle` is ignored.

## Reading the body in middleware

Middleware runs **before** the request body is read, so `req.input(...)` in a middleware sees only the query string and route parameters. This is deliberate: CSRF protection checks the token before it lets the framework read a possibly large body. (With CSRF protection on, a `POST`, `PUT`, `PATCH` or `DELETE` that passed the check has had its body read by it — but don't rely on that.) A middleware that needs the body reads it first:

```dart
@override
Future<void> handle(Request req) async {
  await req.extractBody();
  final email = req.input('email');
  // ...
}
```

Reading it here costs nothing extra later: the body is read once, and the controller gets the same input.

## One instance for every request

The middleware objects you attach to routes are created once, when routes are registered, and shared by every request — including requests running at the same time. Keep per-request data out of their fields:

```dart
class Bad extends Middleware {
  String? userId; // another request can overwrite this before you read it

  @override
  Future<void> handle(Request req) async => userId = req.header('x-user');
}
```

Pass such data on with `req.merge({...})` instead, as in the first example. Fields that hold configuration, or state meant to be shared such as `Throttle`'s counters, are fine.

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
    .middleware([Throttle(maxAttempts: 5, duration: Duration(minutes: 1))]);
```

Five requests per minute per client; excess requests get `429 Too Many Requests` with a `Retry-After` header. Every response carries `X-RateLimit-Limit`, `X-RateLimit-Remaining` (what is left after this request) and `X-RateLimit-Reset` (when the count starts over).

Clients are told apart by IP address, which behind a reverse proxy is the proxy's unless it is listed in `TRUSTED_PROXIES`. Pass `includeUserIdentifier: true` to count each signed-in user separately. Throttling is skipped while `APP_ENV` is `local`; pass `bypassInDevelopment: false` to keep it on. The counts are kept in memory, so they are per process, and per isolate with `APP_ISOLATES`.

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

1. CSRF protection, when it is on and the request changes state (see [Sessions](sessions.md#csrf-tokens))
2. Group middleware (outer groups first, then inner)
3. Route middleware, in the order listed
4. The controller action

A middleware that throws, or that overrides `process` and doesn't call `next()`, stops the chain there.

## Generate a middleware

```bash
vania make:middleware rate_limit
```

This creates `lib/app/http/middleware/rate_limit_middleware.dart` with a skeleton you can fill in.
