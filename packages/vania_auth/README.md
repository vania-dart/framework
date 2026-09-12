# Vania Auth

**Authentication for Vania, done the way you'd expect: hash passwords, issue tokens, protect routes, revoke on logout.**

`vania_auth` gives you a complete, token-based auth stack built on JWT access tokens and database-backed personal access tokens. Because the tokens are persisted, "log me out everywhere" is a real feature, not a wish — you can revoke a single token or all of a user's tokens. It also ships password hashing, multiple guards for apps that authenticate more than one kind of user, and simple ability checks (gates) for authorization.

## Install

```yaml
dependencies:
  vania_auth: ^1.0.0
```

## Set it up once

Wire the stack together at boot. This is the only place the pieces are named:

```dart
import 'package:vania_auth/vania_auth.dart';

void main() async {
  registerMySqlDriver();

  await AuthServiceProvider().register(
    jwtSecretKey: env('APP_KEY'),
    tokenStore: ModelPersonalAccessTokenStore(model: PersonalAccessToken()),
    userProvider: ModelUserProvider(model: User()),
  );

  await Application().initialize(config: config);
}
```

Create the tokens table with `vania make:auth`, then `vania migrate`.

## The everyday flow

```dart
// Hash on the way in — never store a plain password
final user = await User().query.create({
  'email': req.input('email'),
  'password': Auth().hash.make(req.input('password')),
});

// Issue a bearer token
Auth().login(user);
final token = await Auth().createToken(expiresIn: Duration(days: 30));
return Response.json({'token': token['access_token']});
```

Protect routes with the `Authenticate` middleware, then read the current user from `req.user`:

```dart
Router.group(() {
  Router.get('/me', (Request req) => Response.json(req.user));
  Router.post('/logout', authController.logout);
}, middleware: [Authenticate()]);
```

Log out by revoking the token — because it's stored, the server can actually invalidate it:

```dart
await Auth().revokeToken(token);      // one token
await Auth().revokeAllTokens(userId); // every token for a user
```

## What's included

- **JWT access tokens** with configurable lifetimes and optional refresh tokens.
- **Persisted personal access tokens** so revocation and "logout everywhere" work.
- **Password hashing** via `Auth().hash.make` / `Auth().hash.verify`.
- **Guards** — authenticate users, admins, or any number of contexts side by side (`Auth().guard('admin')`).
- **Gates** — named ability checks: `Gate().define('edit-posts', () => ...)`, then `Auth().authorize('edit-posts')`.
- **Pluggable stores** — swap `ModelUserProvider` / `ModelPersonalAccessTokenStore` for your own by implementing the interfaces.

## Links

- Documentation: [vdart.dev/docs](https://vdart.dev/docs/intro)
- Source & issues: [github.com/vania-dart/framework](https://github.com/vania-dart/framework)

## License

MIT
