---
sidebar_position: 8
---

# Sessions

Vania provides file-based sessions with AES-GCM encryption for web applications. Sessions are started automatically for HTML routes and are accessible throughout the request lifecycle.

## Reading Session Data

Session access is asynchronous — reads and writes return a `Future`, so `await` them:

```dart
Future<Response> dashboard(Request req) async {
  final userId = await SessionManager().getSession<int>('user_id');
  final theme = await SessionManager().getSession<String>('theme') ?? 'light';

  return view('dashboard', {'userId': userId, 'theme': theme});
}
```

`getSession<T>()` returns a typed value, or `null` if the key is absent.

## Writing Session Data

```dart
await SessionManager().setSession('user_id', 42);
await SessionManager().setSession('theme', 'dark');
await SessionManager().setSession('cart', {'items': [], 'total': 0.0});
```

Session values can be any JSON-serializable type — strings, numbers, booleans, lists, and maps.

## Deleting Session Data

Remove a specific key:

```dart
await SessionManager().deleteSession('cart');
```

Destroy the entire session:

```dart
await SessionManager().destroyAllSessions();
```

## Session ID

Access the current session identifier:

```dart
String? sessionId = SessionManager().getSessionId();
```

## CSRF Tokens

CSRF protection for web forms is handled for you. In templates, emit the token with the `@csrf` directive (a hidden form field) or `@csrfToken` (the raw value) — see [Views & Templates](views-templates.md). The session layer generates and validates the token behind the scenes; you do not read it from `SessionManager` directly.

## Session Configuration

Sessions are configured through environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `SESSION_LIFETIME` | `9000` | Session duration in seconds |
| `SESSION_CACHE_SIZE` | `5000` | Maximum sessions cached in memory |
| `SECURE_SESSION` | `false` | Set `true` to enable the `Secure` cookie flag |

Session files are stored in `storage/framework/sessions/`. Each session is AES-GCM encrypted using `APP_KEY`, and session IDs are HMAC-SHA256 hashed for filenames.

The session cookie is named `{APP_NAME}_session`, is `httpOnly`, and uses `SameSite=Lax`.

## How Sessions Work

1. When an HTML request arrives, the `SessionManager` checks for the session cookie.
2. If a session ID exists, it loads the encrypted session data from the file store (or in-memory LRU cache).
3. If no session exists, a new one is created.
4. At the end of the request, session data is persisted to the file store.
5. API requests (JSON content type) skip session handling entirely for performance.

## Using Sessions in Templates

Access session data directly in templates:

```html
@if(session('flash_message'))
  <div class="alert alert-success">
    {{ session('flash_message') }}
  </div>
@endif
```
