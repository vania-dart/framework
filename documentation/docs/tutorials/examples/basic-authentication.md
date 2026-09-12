---
sidebar_position: 4
---

# Walkthrough: Basic Authentication

**Sample:** `examples/basic_authentication` · **Needs:** MySQL

This is the smallest complete auth flow: register a user, log in, call a protected route with a bearer token, and log out (revoking the token). It uses `vania_auth` for password hashing and JWT access tokens, backed by a MySQL database.

If you have not read the [Authentication](../../packages/auth.md) package page, skim it first — this walkthrough shows that stack assembled in a real app.

## Run it

Start MySQL and create the database:

```bash
docker run -p 3306:3306 -e MYSQL_ROOT_PASSWORD=secret \
  -e MYSQL_DATABASE=basic_authentication mysql:8
```

Then:

```bash
cd examples/basic_authentication
dart pub get
dart run bin/server.dart
```

```bash
# Register — returns the user and a token
curl -X POST localhost:8000/api/register \
  -H 'Content-Type: application/json' \
  -d '{"name":"Ada","email":"ada@example.com","password":"password123","password_confirmation":"password123"}'

# Call a protected route with the token
curl localhost:8000/api/me -H 'Authorization: Bearer <token>'
```

## Boot: assembling the auth stack

The auth stack is registered in `bin/server.dart`, before the app initialises. This is the one place the pieces are named:

```dart
// bin/server.dart
void main(List<String> arguments) async {
  registerMySqlDriver();

  await AuthServiceProvider().register(
    jwtSecretKey: env('APP_KEY'),
    tokenStore: ModelPersonalAccessTokenStore(model: PersonalAccessToken()),
    userProvider: ModelUserProvider(model: User()),
  );

  await Application().initialize(config: config);
}
```

Three decisions are being made here:

- **`jwtSecretKey`** — the secret that signs and verifies tokens. It comes from `APP_KEY`. Change it and every existing token becomes invalid.
- **`tokenStore`** — where tokens are persisted. `ModelPersonalAccessTokenStore` keeps them in the `personal_access_tokens` table, which is what makes logout (revocation) possible.
- **`userProvider`** — how a user is loaded from a token. `ModelUserProvider` looks users up via the `User` model.

## The models

Two models back the flow. The `User` hides its password from JSON output — a small but important detail so you never accidentally leak a hash:

```dart
// lib/app/models/user.dart
class User extends Model {
  @override
  List<String> get fillable => ['name', 'email', 'password'];
  @override
  List<String> get hidden => ['password'];   // never serialised into responses
}
```

```dart
// lib/app/models/personal_access_token.dart
class PersonalAccessToken extends Model {
  @override
  String get tableName => 'personal_access_tokens';
  @override
  List<String> get fillable =>
      ['name', 'tokenable_id', 'token', 'expires_at', 'last_used_at', 'revoked_at'];
}
```

## The migrations

The two tables the flow needs. Note the token table stores `revoked_at` — that column is how logout works.

```dart
// lib/database/migrations/create_users_table.dart
await create('users', (Schema schema) {
  schema.id();
  schema.string('name');
  schema.string('email').unique();
  schema.string('password');
  schema.timeStamps();
}, true);
```

```dart
// lib/database/migrations/create_personal_access_tokens_table.dart
await create('personal_access_tokens', (Schema schema) {
  schema.id();
  schema.string('name');
  schema.bigInt('tokenable_id');
  schema.string('token').unique();
  schema.timeStamp('expires_at').nullable();
  schema.timeStamp('last_used_at').nullable();
  schema.timeStamp('revoked_at').nullable();
  schema.timeStamps();
}, true);
```

## Register: hash, then issue a token

```dart
// lib/app/http/controllers/auth_controller.dart
Future<Response> register(Request req) async {
  await req.validate({
    'name': 'required|string|max_length:100',
    'email': 'required|email|unique:users',
    'password': 'required|min_length:8|confirmed',
  });

  final user = await User().query.create({
    'name': req.input('name'),
    'email': req.input('email'),
    'password': Auth().hash.make(req.input('password')),  // never store plain text
  });

  Auth().login(user);
  final token = await Auth().createToken(expiresIn: Duration(days: 30));

  return Response.json({'user': user, 'token': token['access_token']}, 201);
}
```

Two rules to internalise:

- `Auth().hash.make(...)` hashes the password before it ever touches the database. You never store what the user typed.
- `'password': 'required|min_length:8|confirmed'` — `confirmed` requires a matching `password_confirmation` field in the request. Validation runs before anything else, so a mismatch is rejected with a `422`.

## Login: verify, then issue

```dart
Future<Response> login(Request req) async {
  await req.validate({'email': 'required|email', 'password': 'required'});

  final user = await User().query.where('email', '=', req.input('email')).first();

  if (user == null || !Auth().hash.verify(req.input('password'), user['password'])) {
    return Response.json({'message': 'Invalid credentials'}, 401);
  }

  Auth().login(user);
  final token = await Auth().createToken(expiresIn: Duration(days: 30));
  return Response.json({'user': user, 'token': token['access_token']});
}
```

`Auth().hash.verify(plain, hash)` compares the submitted password against the stored hash. The same `'Invalid credentials'` message is returned whether the email is unknown or the password is wrong — so an attacker cannot tell which emails are registered.

## Logout: revoke the token

```dart
Future<Response> logout(Request req) async {
  final authorization = req.header('authorization');
  if (authorization != null) {
    final token = authorization.replaceFirst('Bearer ', '');
    await Auth().revokeToken(token);
  }
  return Response.json({'message': 'Logged out'});
}
```

Because tokens are persisted, revoking one marks it invalid on the server. A JWT is otherwise valid until it expires — the token store is what gives you a real "log me out now" button.

## Protecting routes

Public and protected routes live in the same file. The protected ones are wrapped in a group guarded by the `Authenticate()` middleware:

```dart
// lib/route/api_route.dart
// Public
Router.post('/register', authController.register);
Router.post('/login', authController.login);

// Protected — require a valid bearer token
Router.group(() {
  Router.get('/me', authController.me);
  Router.post('/logout', authController.logout);
}, middleware: [Authenticate()]);
```

`Authenticate()` reads the `Authorization: Bearer …` header, verifies the token against the store, loads the user, and makes it available as `req.user` inside the handler:

```dart
Future<Response> me(Request req) async => Response.json(req.user);
```

If the token is missing, invalid, expired, or revoked, the request never reaches the controller — the middleware rejects it with a `401`.

## Tests without a database

The test suite drives the real `Auth` service through register → login → verify → logout, but supplies **in-memory** implementations of `UserProvider` and `PersonalAccessTokenStore`. So the whole flow is tested with no MySQL running:

```bash
dart test
```

This is the same "swap the implementation behind an interface" idea from the [Todos](todos.md) and [DDD Wallet](ddd-wallet.md) samples, applied to the auth stores.

## What to take away

- Assemble the auth stack once in `bin/server.dart`: secret, token store, user provider.
- **Hash on the way in, verify on the way through** — never store or compare plain passwords.
- Persisted tokens are what make revocation (logout) real.
- Guard routes with `Authenticate()`; read the current user via `req.user`.
- `hidden` on a model keeps secrets out of JSON responses.
