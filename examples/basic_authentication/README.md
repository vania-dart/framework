# Basic Authentication Example

A minimal, token-based authentication API built with the [Vania](../../packages/core) framework.
It shows the smallest end-to-end auth setup: register, login, an authenticated
route, and logout — using `vania_auth` for password hashing and JWT access tokens,
backed by MySQL.

## What it demonstrates

- Registering the auth stack in `bin/server.dart` via `AuthServiceProvider`
  (JWT secret + `ModelPersonalAccessTokenStore` + `ModelUserProvider`).
- Hashing passwords with `Auth().hash` and never storing them in plain text.
- Issuing a bearer token with `Auth().createToken(...)`.
- Protecting routes with the `Authenticate()` middleware.
- Revoking a token on logout with `Auth().revokeToken(...)`.

## Layout

```
lib/
  config/app.dart                     # app + database config
  route/api_route.dart                # public + protected routes
  app/http/controllers/auth_controller.dart
  app/models/user.dart
  app/models/personal_access_token.dart
  app/providers/route_service_provider.dart
  database/migrations/                # users + personal_access_tokens tables
bin/server.dart                       # boot: driver + auth + Application
test/basic_authentication_test.dart   # DB-free integration test of the auth flow
```

## Endpoints

| Method | Path            | Auth   | Description                        |
|--------|-----------------|--------|------------------------------------|
| POST   | `/api/register` | public | Create a user, return a token      |
| POST   | `/api/login`    | public | Verify credentials, return a token |
| GET    | `/api/me`       | bearer | The authenticated user             |
| POST   | `/api/logout`   | bearer | Revoke the current token           |

## Running

1. Create a MySQL database named `basic_authentication` (or set the `DB_*`
   env vars in `config/app.dart`) and set `APP_KEY` to a JWT secret.
2. Run the migrations, then start the server:

   ```bash
   dart pub get
   dart run bin/server.dart
   ```

## Tests

The test suite drives the real `Auth` service through the full
register → login → verify → logout flow using in-memory implementations of
`UserProvider` and `PersonalAccessTokenStore`, so it runs without a database:

```bash
dart test
```
