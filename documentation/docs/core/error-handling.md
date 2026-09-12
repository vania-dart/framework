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

// 500 Internal Server Error
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

## Error Response Format

### JSON Requests

For API requests, exceptions are returned as JSON:

```json
{
  "message": "User not found"
}
```

### HTML Requests

For web requests, the framework renders error view templates if they exist:

- `views/errors/404.html` for 404 errors
- `views/errors/500.html` for 500 errors
- `views/errors/419.html` for CSRF failures

If the view file does not exist, a plain text response is returned.

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

For HTML requests, the user is redirected back with errors and old input in the session.

## Database Errors

`DatabaseException` and `QueryException` are caught by the request handler. In debug mode (`APP_DEBUG=true`), the full error message is returned. In production, a generic "Internal Server Error" message is shown.

## Unhandled Exceptions

Any exception not caught by your code is caught by the request pipeline. It logs the error and returns a 500 response. In debug mode, the exception message and stack trace are included in the response.
