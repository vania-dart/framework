---
sidebar_position: 4
---

# Test-Driven Development (TDD)

TDD is not a project structure — it is a development workflow. You write a failing test first, then write the minimum code to make it pass, then refactor. This guide shows how to apply TDD with Vania and organize your tests.

## Test Directory Structure

```
my_app/
├── lib/
│   ├── app/
│   │   ├── http/controllers/
│   │   ├── models/
│   │   └── services/
│   └── database/
│       └── migrations/
├── test/
│   ├── unit/
│   │   ├── models/
│   │   │   ├── user_test.dart
│   │   │   └── post_test.dart
│   │   ├── services/
│   │   │   ├── auth_service_test.dart
│   │   │   └── post_service_test.dart
│   │   └── validation/
│   │       └── email_validation_test.dart
│   ├── integration/
│   │   ├── database/
│   │   │   ├── user_repository_test.dart
│   │   │   └── post_query_test.dart
│   │   └── api/
│   │       ├── auth_api_test.dart
│   │       ├── user_api_test.dart
│   │       └── post_api_test.dart
│   ├── helpers/
│   │   ├── test_database.dart
│   │   └── test_factory.dart
│   └── fixtures/
│       └── sample_data.dart
└── pubspec.yaml
```

## The TDD Cycle

### Step 1: Write a Failing Test

```dart
// test/unit/services/post_service_test.dart
import 'package:test/test.dart';
import 'package:my_app/app/services/post_service.dart';

void main() {
  group('PostService', () {
    late PostService service;

    setUp(() {
      service = PostService();
    });

    test('createPost requires a title', () {
      expect(
        () => service.validatePost({'body': 'content'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('createPost requires a body', () {
      expect(
        () => service.validatePost({'title': 'My Post'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('createPost accepts valid data', () {
      final result = service.validatePost({
        'title': 'My Post',
        'body': 'Post content here',
      });
      expect(result, isTrue);
    });

    test('slug is generated from title', () {
      expect(service.generateSlug('Hello World!'), equals('hello-world'));
      expect(service.generateSlug('  Dart & Vania  '), equals('dart-vania'));
    });
  });
}
```

Run it — it fails because `PostService` does not exist yet:

```bash
dart test test/unit/services/post_service_test.dart
```

### Step 2: Write the Minimum Code

```dart
// lib/app/services/post_service.dart
class PostService {
  bool validatePost(Map<String, dynamic> data) {
    if (data['title'] == null || (data['title'] as String).isEmpty) {
      throw ArgumentError('Title is required');
    }
    if (data['body'] == null || (data['body'] as String).isEmpty) {
      throw ArgumentError('Body is required');
    }
    return true;
  }

  String generateSlug(String title) {
    return title
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }
}
```

Run the test again — it passes.

### Step 3: Refactor

Clean up while tests stay green. Add edge cases. Repeat.

## Testing Database Queries

For integration tests that hit the database:

```dart
// test/helpers/test_database.dart
import 'package:vania/database.dart';

Future<void> setupTestDatabase() async {
  registerMySqlDriver();
  await ConnectionManager().connect(
    DBConfig(
      driver: 'mysql',
      host: 'localhost',
      database: 'my_app_test',
      username: 'root',
      password: 'secret',
    ),
    'test',
  );
  ConnectionManager().defaultConnection = 'test';
}

Future<void> teardownTestDatabase() async {
  await ConnectionManager().connection()?.close();
}
```

```dart
// test/integration/database/user_repository_test.dart
import 'package:test/test.dart';
import 'package:vania/database.dart';
import '../../helpers/test_database.dart';

void main() {
  setUpAll(() async => await setupTestDatabase());
  tearDownAll(() async => await teardownTestDatabase());

  setUp(() async {
    await DB.table('users').truncate();
  });

  group('User queries', () {
    test('creates a user and retrieves it', () async {
      var id = await DB.table('users').insertGetId({
        'name': 'Alice',
        'email': 'alice@example.com',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      var user = await DB.table('users').find(id);
      expect(user?['name'], equals('Alice'));
      expect(user?['email'], equals('alice@example.com'));
    });

    test('soft deletes a user', () async {
      var id = await DB.table('users').insertGetId({
        'name': 'Bob',
        'email': 'bob@example.com',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await User().query.where('id', '=', id).delete();

      var regular = await User().query.find(id);
      expect(regular, isNull);

      var withDeleted = await User().query.withSoftDeletes().find(id);
      expect(withDeleted, isNotNull);
    });
  });
}
```

## Testing Controllers

Test controller logic without HTTP by calling methods directly:

```dart
// test/unit/controllers/post_controller_test.dart
import 'package:test/test.dart';
import 'package:my_app/app/services/post_service.dart';

void main() {
  group('PostController logic', () {
    late PostService service;

    setUp(() {
      service = PostService();
    });

    test('rejects empty title', () {
      expect(
        () => service.validatePost({'title': '', 'body': 'content'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('generates correct slug for special characters', () {
      expect(service.generateSlug('Café & Résumé'), equals('caf-rsum'));
    });
  });
}
```

## Running Tests

```bash
# Run all tests
dart test

# Run a specific test file
dart test test/unit/services/post_service_test.dart

# Run tests matching a name pattern
dart test --name "creates a user"

# Run with coverage
dart test --coverage=coverage
```

## When to Use TDD

- When building business logic with clear inputs and outputs.
- When fixing a bug — write the failing test first, then fix.
- When the requirements are well-defined and testable.
- When you want confidence that refactoring does not break behavior.

## Key Principles

1. **Red → Green → Refactor.** Write the test, make it pass, clean up. Never skip the test-first step.
2. **Test behavior, not implementation.** Test what a method returns or what side effects it has, not how it does it internally.
3. **Unit tests are fast.** No database, no network, no filesystem. Pure logic.
4. **Integration tests hit real infrastructure.** Use a test database. Truncate between tests.
5. **Tests are documentation.** A well-named test describes what the system does. Future developers read tests to understand behavior.
