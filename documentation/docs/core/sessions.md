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

### After signing in

Give the session a new id whenever a user signs in, or their privileges change:

```dart
await regenerateSession();
await setSession('logged_in', true);
```

The data stays; only the id changes, and the old one stops working. Someone who learned the old id — by planting a cookie in the browser before the user signed in, say — is left holding nothing. For the same reason, an id the server never issued is not taken up: a request carrying one starts a fresh session with an id of the server's choosing. That holds for an API call made with `fetch` as much as for a page, so a session written by a JSON login lands under a new id too.

## CSRF Tokens

CSRF protection is off until you turn it on:

```env
CSRF_PROTECTION_ENABLED=true
```

From then on every `POST`, `PUT`, `PATCH` and `DELETE` request must carry the session's token, or it is refused with a `419`. `GET`, `HEAD`, `OPTIONS` and `QUERY` change nothing, so they need none. Routes under `api/` are left out, since an API normally authenticates with a token rather than the session cookie; set `csrf_protect_api: true` in the config map if yours uses the cookie, and list any other paths to leave out under `csrf_except`.

In templates, emit the token with the `@csrf` directive (a hidden form field) or `@csrfToken` (the raw value) — see [Views & Templates](views-templates.md). A request sent from JavaScript, which is the only way to send a `PUT`, `PATCH` or `DELETE` from a page, passes it in the `X-CSRF-TOKEN` header instead. The session layer generates and validates the token behind the scenes; you do not read it from `SessionManager` directly.

## Session Configuration

Sessions are configured through environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `SESSION_LIFETIME` | `9000` | Seconds a session lasts, for both the cookie and the stored session |
| `SESSION_CACHE_SIZE` | `5000` | Maximum sessions cached in memory |
| `SECURE_SESSION` | `true` | Sends the cookie only over HTTPS; set `false` for local development over plain HTTP |

A session that is in use stays alive: once it is past half its lifetime, the next request renews it. So an idle session ends between half and all of `SESSION_LIFETIME` after its last request. Expired session files are swept from disk about once an hour.

Session files are stored in `storage/framework/sessions/`. Each session is AES-GCM encrypted using `APP_KEY`, and session IDs are HMAC-SHA256 hashed for filenames.

The session cookie is named `{APP_NAME}_session`, is `httpOnly`, and uses `SameSite=Lax`.

## How Sessions Work

1. When a request asks for HTML (its `Accept` header) in an app that renders pages, the `SessionManager` checks for the session cookie.
2. If the cookie names an existing session, its encrypted data is loaded from the file store (or the in-memory LRU cache).
3. Otherwise a new session is started, under a new id.
4. Changes are saved once, just before the response is written, and only if there were any.
5. Every other request — an API call, or any request to an app without views — has no session at all.

## Using Sessions in Templates

Access session data directly in templates:

```html
@if(session('flash_message'))
  <div class="alert alert-success">
    {{ session('flash_message') }}
  </div>
@endif
```
