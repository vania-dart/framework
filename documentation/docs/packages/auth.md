---
sidebar_position: 1
---

# Authentication (vania_auth)

The `vania_auth` package provides a complete authentication system: JWT token generation and verification, password hashing, guard-based multi-auth, personal access tokens, and authorization gates.

## Installation

```yaml
dependencies:
  vania_auth: ^1.0.0
```

## Setup

### 1. Create the Personal Access Tokens Table

```bash
vania make:auth
```

This generates a migration for the `personal_access_tokens` table where token hashes are stored.

Run the migration:

```bash
vania migrate
```

### 2. Configure the Auth Service Provider

In your `bin/server.dart` or a dedicated provider:

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

### 3. Configure Auth Guards

In `lib/config/auth.dart`:

```dart
import 'package:my_app/app/models/user.dart';

Map<String, dynamic> authConfig = {
  'guards': {
    'default': {
      'provider': User(),
    },
  },
};
```

## Authenticating Users

### Login (Issue a Token)

```dart
class AuthController extends Controller {
  Future<Response> login(Request req) async {
    req.validate({
      'email': 'required|email',
      'password': 'required',
    });

    final user = await User().query
        .firstWhere('email', '=', req.input('email'));

    if (user == null || !Auth().hash.verify(req.input('password'), user['password'])) {
      return Response.json({'message': 'Invalid credentials'}, 401);
    }

    Auth().login(user);
    final tokenData = await Auth().createToken(expiresIn: Duration(days: 30));

    return Response.json({
      'token': tokenData['access_token'],
      'user': user,
    });
  }
}
```

### Protecting Routes

Use the `Authenticate` middleware:

```dart
Router.group(() {
  Router.get('/profile', userController.profile);
  Router.put('/profile', userController.updateProfile);
  Router.post('/logout', authController.logout);
}, middleware: [Authenticate()]);
```

### Accessing the Authenticated User

```dart
Future<Response> profile(Request req) async {
  var user = req.user;
  return Response.json(user);
}
```

### Token Verification

```dart
bool valid = await Auth().check(token);
```

### Refresh Tokens

```dart
Future<Response> refresh(Request req) async {
  final refreshToken = req.input('refresh_token');
  final tokenData = await Auth().createTokenByRefreshToken(refreshToken);
  return Response.json(tokenData);
}
```

### Logout (Revoke Token)

```dart
Future<Response> logout(Request req) async {
  final token = req.header('authorization')?.replaceFirst('Bearer ', '');
  if (token != null) {
    await Auth().revokeToken(token);
  }
  return Response.json({'message': 'Logged out'});
}

// Revoke all tokens for a user
await Auth().revokeAllTokens(userId);
```

## Password Hashing

```dart
// Hash a password
String hashed = Auth().hash.make('my_password');

// Verify a password
bool matches = Auth().hash.verify('my_password', hashed);
```

The default hasher uses HMAC-SHA512 with 600,000 iterations.

## Authorization (Gates)

Define abilities and check them:

Abilities are named boolean checks registered on `Gate()`. Register them once at startup, then check them by name:

```dart
// Define an ability (the callback returns a bool)
Gate().define('edit-posts', () => Auth().user?['role'] == 'editor');

// Check it
if (Auth().authorize('edit-posts')) {
  // allowed
}

if (Auth().denies('edit-posts')) {
  // not allowed
}
```

`authorize` and `denies` take only the ability name; the ability's own closure decides the result (typically by reading `Auth().user`).

## Guard-Based Multi-Auth

Support multiple authentication contexts (e.g., users and admins):

```dart
// Configure multiple guards
Auth().configureGuard('admin',
  tokenStore: ModelPersonalAccessTokenStore(model: PersonalAccessToken()),
  userProvider: ModelUserProvider(model: Admin()),
);

// Login as admin
Auth().guard('admin').login(adminUser);
var token = await Auth().guard('admin').createToken();

// Check admin auth
Auth().guard('admin').check(token);
```

## Middleware Options

### Authenticate

Validates bearer tokens and loads the user:

```dart
Router.get('/api/me', handler).middleware([Authenticate()]);
```

### RedirectIfAuthenticated

For guest-only routes (login, register pages):

```dart
Router.get('/login', authController.showLogin)
    .middleware([RedirectIfAuthenticated()]);
```

## Token Store Customization

The default `ModelPersonalAccessTokenStore` stores tokens in the database. You can customize column mapping:

```dart
ModelPersonalAccessTokenStore(
  columns: TokenStoreColumns(
    id: 'id',
    tokenableType: 'tokenable_type',
    tokenableId: 'tokenable_id',
    name: 'name',
    token: 'token',
    abilities: 'abilities',
    lastUsedAt: 'last_used_at',
    expiresAt: 'expires_at',
    createdAt: 'created_at',
    updatedAt: 'updated_at',
  ),
);
```

## User Provider

The `ModelUserProvider` works with any ORM model. Customize the columns:

```dart
ModelUserProvider(
  model: User(),
  emailColumn: 'email',
  passwordColumn: 'password',
);
```

Or implement `UserProvider` directly for custom logic:

```dart
class CustomUserProvider implements UserProvider {
  @override
  Future<Map<String, dynamic>?> findById(dynamic id) async { ... }

  @override
  Future<Map<String, dynamic>?> findByEmail(String email) async { ... }

  @override
  bool validatePassword(String plain, String hashed) { ... }

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async { ... }

  @override
  String get idKey => 'id';
}
```
