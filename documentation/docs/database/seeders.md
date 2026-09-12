---
sidebar_position: 6
---

# Seeders & Factories

Seeders populate your database with test or initial data. Factories generate realistic fake data for your models.

## Writing a Seeder

Create a class that extends `Seeder`:

```dart
import 'package:vania/database.dart';

class UserSeeder extends Seeder {
  @override
  Future<void> run() async {
    await DB.table('users').insertMany([
      {
        'name': 'Admin User',
        'email': 'admin@example.com',
        'password': Hash().make('password'),
        'role': 'admin',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'name': 'Test User',
        'email': 'user@example.com',
        'password': Hash().make('password'),
        'role': 'user',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
    ]);
  }
}
```

## Running Seeders

Use the `SeederRunner`:

```dart
void main() async {
  await SeederRunner().setup(
    database: DBConfig(
      driver: 'mysql',
      host: 'localhost',
      database: 'my_app',
      username: 'root',
      password: 'secret',
    ),
    seeders: [
      UserSeeder(),
      PostSeeder(),
      CategorySeeder(),
    ],
  );
}
```

Or via CLI:

```bash
vania migrate:seed
```

### Protected environments

Like migrations, seeding is refused when `APP_ENV` is `staging` or
`production`, and `--force` overrides it. For the flag to reach the runner,
forward your script's arguments:

```dart
void main(List<String> args) async {
  await SeederRunner().setup(
    database: ...,
    seeders: [UserSeeder()],
    args: args,
  );
}
```

```bash
vania migrate:seed --force
```

## Seeder Factories

Factories generate randomized test data. Extend `SeederFactory`:

```dart
import 'package:vania/database.dart';

class UserFactory extends SeederFactory {
  UserFactory() : super('users');

  @override
  Map<String, dynamic> definition() {
    return {
      'name': randomName(),
      'email': randomEmail(),
      'password': Hash().make('password'),
      'phone': randomPhone(),
      'role': randomElement(['admin', 'editor', 'user']),
      'bio': randomText(maxWords: 20),
      'created_at': randomPastDate().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
```

### Built-in Random Generators

| Method | Description | Example Output |
|--------|-------------|----------------|
| `randomInt(min, max)` | Random integer | `42` |
| `randomDouble(min, max)` | Random double | `19.95` |
| `randomBool()` | Random boolean | `true` |
| `randomElement(list)` | Pick from list | `'admin'` |
| `randomString(length)` | Random alphanumeric | `'a8f3b2c1'` |
| `randomEmail()` | Fake email | `'user_a8f3@example.com'` |
| `randomName()` | Random full name | `'Alice Johnson'` |
| `randomPhone()` | Random phone number | `'+1-555-0123'` |
| `randomDate(start, end)` | Date in range | `DateTime(2026, 3, 15)` |
| `randomPastDate()` | Date in the past | `DateTime(2025, 8, 22)` |
| `randomFutureDate()` | Date in the future | `DateTime(2027, 1, 10)` |
| `randomUuid()` | UUID v4 | `'550e8400-e29b-...'` |
| `randomText({maxWords})` | Lorem-like text | `'quick brown fox...'` |
| `randomPrice(min, max)` | Price decimal | `29.99` |
| `randomStatus(statuses)` | Pick a status | `'active'` |

### Using Factories

Factories build data maps — they do not touch the database themselves. Generate rows, then insert them:

```dart
// One generated row (a Map)
var userData = UserFactory().make();

// With overrides
var admin = UserFactory().make({'role': 'admin', 'name': 'Super Admin'});

// Many rows at once
var users = UserFactory().makeMany(10);

// Persist by handing the generated data to the query builder
await DB.table('users').insertMany(UserFactory().makeMany(50));
```

> `create()` and `createMany()` are aliases of `make()` / `makeMany()` — they return the same data maps and do **not** save. To persist, pass the result to `insert` / `insertMany`, typically from inside a seeder's `run()`.

### Using Factories in Seeders

```dart
class UserSeeder extends Seeder {
  @override
  Future<void> run() async {
    // Insert one specific admin row
    await DB.table('users').insert(UserFactory().make({
      'name': 'Admin',
      'email': 'admin@example.com',
      'role': 'admin',
    }));

    // Insert 100 generated users
    await DB.table('users').insertMany(UserFactory().makeMany(100));
  }
}
```

## Generating Seeders via CLI

```bash
vania make:seeder
```
