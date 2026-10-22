---
sidebar_position: 15
---

# Error Handling

Vania provides a set of HTTP exception classes and automatic error handling throughout the request pipeline. Unhandled exceptions are caught, logged, and returned as appropriate error responses.

## Throwing HTTP Exceptions

Use the built-in exception classes to return error responses:

Every exception takes a named `message:` argument:

```dart
import 'package:vania/vania.dart';

// 404 Not Found
throw NotFoundException(message: 'User not found');

// 403 Forbidden
throw ForbiddenException(message: 'You do not have access');

// 401 Unauthorized
throw Unauthenticated(message: 'Invalid credentials');

// 500 Internal Server Error — the client sees the message only in debug
throw InternalServerError(message: 'Something went wrong');

// Custom HTTP status — the class is HttpResponseException, with a `code`
throw HttpResponseException(message: 'Too many requests', code: 429);
```

## Available Exception Classes

| Exception | Status Code | Use Case |
|-----------|-------------|----------|
| `NotFoundException` | 404 | Resource not found |
| `ForbiddenException` | 403 | Insufficient permissions |
| `Unauthenticated` | 401 | Authentication required or failed |
| `UnauthorizedException` | 401 | Authorization denied |
| `InternalServerError` | 500 | Unexpected server error |
| `ValidationException` | 422 | Validation failure (thrown by the validator) |
| `ThrottleException` | 429 | Rate limit exceeded |
| `PageExpiredException` | 419 | CSRF token mismatch |
| `HttpResponseException` | Any (`code`) | Custom HTTP error |
| `RedirectException` | 302 | Force a redirect |
| `DatabaseException` | 500 | Database connection or query error |
| `QueryException` | 500 | SQL query error |
| `InvalidArgumentException` | 500 | Bad argument passed to framework code |

## Rejecting from middleware

Middleware rejects a request by **throwing** one of these exceptions — there is no `abort()` helper. Returning from `handle` continues the chain; throwing stops it and produces the matching response:

```dart
class AdminMiddleware extends Middleware {
  @override
  Future<void> handle(Request req) async {
    if (!isAdmin(req)) {
      throw ForbiddenException(message: 'Admin access required');
    }
  }
}
```

See [Middleware](middleware.md) for the full `handle` / `process` model.

An exception gets the same response whether a middleware or the controller threw it.

## Error Response Format

### JSON Requests

For API requests, exceptions are returned as JSON:

```json
{
  "message": "User not found"
}
```

A 5xx exception you throw yourself is treated like any other server failure: it is logged, and its message reaches the client only when `APP_DEBUG=true`. Messages of 4xx exceptions are written for the client and always shown.

### HTML Requests

A request that asks for HTML, in an app that renders pages (it has views, or CSRF protection on), gets HTML instead:

- `RedirectException` redirects to its `message`. So does an `Unauthenticated` created with `responseType: ResponseType.html`, which is how a session guard sends a browser to its login page: `Unauthenticated(message: '/login', responseType: ResponseType.html)`. Any other `Unauthenticated` is a `401`, even for a browser — its message is text for the client, not an address.
- A 404, 500 or 419 (CSRF failure) renders `lib/resources/view/errors/404.html`, `500.html` or `419.html`, when it exists.
- Anything else, or a missing view, is a plain HTML page with the status code and the escaped message.

An app without views answers in JSON, even a browser.

## Validation Errors

Validation failures return a `422` response with structured error data:

```json
{
  "message": "Validation failed",
  "errors": {
    "email": ["The email field is required."],
    "password": ["The password must be at least 8 characters."]
  }
}
```

For HTML requests, the user is redirected back with errors and old input in the session. An app without sessions (no views and CSRF off) has nowhere to keep them across a redirect, so it answers HTML requests with the `422` too.

## Database Errors

`DatabaseException` and `QueryException` are caught by the request handler. In debug mode (`APP_DEBUG=true`), the full error message is returned. In production, a generic "Internal Server Error" message is shown.

## Unhandled Exceptions

Any exception not caught by your code is caught by the request pipeline. It logs the error with its stack trace and returns a 500 response. In debug mode, the exception message is included in the response; the stack trace only goes to the log.
