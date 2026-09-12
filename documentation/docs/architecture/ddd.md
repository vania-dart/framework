---
sidebar_position: 2
---

# Domain-Driven Design (DDD)

DDD organizes your application around business domains. Each domain encapsulates its own entities, value objects, repositories, and services. The HTTP layer becomes a thin adapter that translates between web requests and domain operations.

## Directory Structure

```
my_app/
├── bin/
│   └── server.dart
├── lib/
│   ├── config/
│   │   ├── app.dart
│   │   ├── auth.dart
│   │   └── cors.dart
│   ├── domain/
│   │   ├── user/
│   │   │   ├── entities/
│   │   │   │   └── user.dart
│   │   │   ├── value_objects/
│   │   │   │   ├── email.dart
│   │   │   │   └── password.dart
│   │   │   ├── repositories/
│   │   │   │   └── user_repository.dart
│   │   │   ├── services/
│   │   │   │   └── user_registration_service.dart
│   │   │   └── exceptions/
│   │   │       └── user_not_found_exception.dart
│   │   ├── post/
│   │   │   ├── entities/
│   │   │   │   ├── post.dart
│   │   │   │   └── comment.dart
│   │   │   ├── value_objects/
│   │   │   │   └── post_status.dart
│   │   │   ├── repositories/
│   │   │   │   └── post_repository.dart
│   │   │   ├── services/
│   │   │   │   ├── post_publishing_service.dart
│   │   │   │   └── comment_moderation_service.dart
│   │   │   └── events/
│   │   │       ├── post_published.dart
│   │   │       └── comment_added.dart
│   │   └── order/
│   │       ├── entities/
│   │       ├── value_objects/
│   │       ├── repositories/
│   │       └── services/
│   ├── infrastructure/
│   │   ├── persistence/
│   │   │   ├── models/
│   │   │   │   ├── user_model.dart
│   │   │   │   ├── post_model.dart
│   │   │   │   └── comment_model.dart
│   │   │   ├── repositories/
│   │   │   │   ├── db_user_repository.dart
│   │   │   │   └── db_post_repository.dart
│   │   │   └── migrations/
│   │   │       ├── create_users_table.dart
│   │   │       ├── create_posts_table.dart
│   │   │       └── migrate.dart
│   │   ├── mail/
│   │   │   └── welcome_email.dart
│   │   └── cache/
│   │       └── post_cache_repository.dart
│   ├── application/
│   │   ├── user/
│   │   │   ├── register_user_command.dart
│   │   │   ├── register_user_handler.dart
│   │   │   ├── get_user_query.dart
│   │   │   └── get_user_handler.dart
│   │   └── post/
│   │       ├── create_post_command.dart
│   │       ├── create_post_handler.dart
│   │       ├── publish_post_command.dart
│   │       └── list_posts_handler.dart
│   ├── interfaces/
│   │   ├── http/
│   │   │   ├── controllers/
│   │   │   │   ├── user_controller.dart
│   │   │   │   └── post_controller.dart
│   │   │   ├── middleware/
│   │   │   │   └── authenticate.dart
│   │   │   ├── routes/
│   │   │   │   ├── api_routes.dart
│   │   │   │   └── web_routes.dart
│   │   │   └── validators/
│   │   │       ├── register_user_validation.dart
│   │   │       └── create_post_validation.dart
│   │   └── websocket/
│   │       └── notification_handler.dart
│   └── providers/
│       ├── route_service_provider.dart
│       ├── domain_service_provider.dart
│       └── repository_service_provider.dart
└── test/
    ├── domain/
    │   ├── user/
    │   │   └── user_registration_service_test.dart
    │   └── post/
    │       └── post_publishing_service_test.dart
    ├── application/
    │   └── post/
    │       └── create_post_handler_test.dart
    └── infrastructure/
        └── persistence/
            └── db_post_repository_test.dart
```

## The Four Layers

### 1. Domain Layer (`lib/domain/`)

Pure business logic with no framework dependencies.

```dart
// lib/domain/user/entities/user.dart
class UserEntity {
  final int id;
  final String name;
  final Email email;
  final DateTime createdAt;

  UserEntity({required this.id, required this.name, required this.email, required this.createdAt});
}

// lib/domain/user/value_objects/email.dart
class Email {
  final String value;

  Email(this.value) {
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
      throw ArgumentError('Invalid email: $value');
    }
  }

  @override
  String toString() => value;
}

// lib/domain/user/repositories/user_repository.dart
abstract class UserRepository {
  Future<UserEntity?> findById(int id);
  Future<UserEntity?> findByEmail(String email);
  Future<UserEntity> save(UserEntity user);
  Future<void> delete(int id);
}
```

### 2. Application Layer (`lib/application/`)

Orchestrates domain operations. Uses commands/queries to represent user intentions.

```dart
// lib/application/user/register_user_command.dart
class RegisterUserCommand {
  final String name;
  final String email;
  final String password;

  RegisterUserCommand({required this.name, required this.email, required this.password});
}

// lib/application/user/register_user_handler.dart
class RegisterUserHandler {
  final UserRepository _userRepo;
  final UserRegistrationService _registrationService;

  RegisterUserHandler(this._userRepo, this._registrationService);

  Future<UserEntity> handle(RegisterUserCommand command) async {
    return await _registrationService.register(
      name: command.name,
      email: Email(command.email),
      password: command.password,
    );
  }
}
```

### 3. Infrastructure Layer (`lib/infrastructure/`)

Implements domain interfaces using framework tools (ORM, cache, mail):

```dart
// lib/infrastructure/persistence/repositories/db_user_repository.dart
import 'package:vania/database.dart';
import 'package:my_app/domain/user/entities/user.dart';
import 'package:my_app/domain/user/repositories/user_repository.dart';

class DbUserRepository implements UserRepository {
  @override
  Future<UserEntity?> findById(int id) async {
    final row = await User().query.find(id);
    return row != null ? _toEntity(row) : null;
  }

  @override
  Future<UserEntity> save(UserEntity user) async {
    final data = await User().query.create({
      'name': user.name,
      'email': user.email.toString(),
    });
    return _toEntity(data);
  }

  UserEntity _toEntity(Map<String, dynamic> row) {
    return UserEntity(
      id: row['id'],
      name: row['name'],
      email: Email(row['email']),
      createdAt: DateTime.parse(row['created_at']),
    );
  }

  // ...
}
```

### 4. Interface Layer (`lib/interfaces/`)

HTTP controllers translate between web requests and application commands:

```dart
// lib/interfaces/http/controllers/user_controller.dart
class UserController extends Controller {
  final RegisterUserHandler _registerHandler;

  UserController(this._registerHandler);

  Future<Response> register(Request req) async {
    req.validate(RegisterUserValidation());

    final user = await _registerHandler.handle(RegisterUserCommand(
      name: req.input('name'),
      email: req.input('email'),
      password: req.input('password'),
    ));

    return Response.json({'id': user.id, 'name': user.name}, 201);
  }
}
```

## Wiring It Together

Use service providers to bind interfaces to implementations:

```dart
// lib/providers/repository_service_provider.dart
class RepositoryServiceProvider extends ServiceProvider {
  @override
  Future<void> register() async {
    IoCContainer().register<UserRepository>(
      () => DbUserRepository(),
      singleton: true,
    );
    IoCContainer().register<PostRepository>(
      () => DbPostRepository(),
      singleton: true,
    );
  }

  @override
  Future<void> boot() async {}
}
```

## When to Use This

- Your application has complex business rules that change independently of the UI or database.
- Multiple interfaces (HTTP API, gRPC, CLI) share the same business logic.
- You have a dedicated team that thinks in terms of business domains.
- The project will live for years and the business logic will evolve significantly.

## Key Principles

1. **Domain layer has zero framework imports.** It is pure Dart.
2. **Dependencies point inward.** Infrastructure depends on domain, not the other way around.
3. **Application layer coordinates.** It does not contain business rules — those live in domain services.
4. **Interfaces are thin.** Controllers do validation and translation, nothing else.
