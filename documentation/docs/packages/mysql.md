---
sidebar_position: 2
---

# MySQL Driver (vania_mysql)

`vania_mysql` is the MySQL (and MariaDB) driver for Vania's ORM. It plugs a real MySQL connection into the shared database layer that lives in the core package, so everything you read in the [Database & ORM](../database/getting-started.md) section — the query builder, models, relationships, migrations, and seeders — works unchanged once this driver is registered.

The driver is deliberately thin. It contributes exactly one thing: the connection that speaks the MySQL wire protocol. All the portable behaviour ships in `vania` itself.

## Installation

```yaml
dependencies:
  vania: ^2.0.0
  vania_mysql: ^1.0.0
```

Then:

```bash
dart pub get
```

## Configuration

Set your connection details in `.env`:

```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=my_app
DB_USERNAME=root
DB_PASSWORD=secret
```

Describe the connection in `config/app.dart` and add the `DatabaseServiceProvider`:

```dart
Map<String, dynamic> config = {
  'database': {
    'default': env('DB_CONNECTION', 'mysql'),
    'connections': {
      'mysql': {
        'driver': 'mysql',
        'host': env('DB_HOST', 'localhost'),
        'port': env<int>('DB_PORT', 3306),
        'database': env('DB_DATABASE', 'my_app'),
        'username': env('DB_USERNAME', 'root'),
        'password': env('DB_PASSWORD', ''),
      },
    },
  },
  'providers': <ServiceProvider>[
    RouteServiceProvider(),
    DatabaseServiceProvider(),
  ],
};
```

## Registering the driver

This is the one line that ties your app to MySQL specifically. Call `registerMySqlDriver()` in `bin/server.dart` **before** `Application().initialize`:

```dart
import 'package:vania/vania.dart';
import 'package:vania_mysql/vania_mysql.dart';
import 'package:my_app/config/app.dart';

void main() async {
  registerMySqlDriver();

  await Application().initialize(config: config);
}
```

That is the only place the name `vania_mysql` needs to appear. The rest of your app imports `package:vania/database.dart` and never mentions the driver. Swapping to PostgreSQL later means changing this one call and the connection config — not your models, migrations, or queries.

## What you get

Once registered, use the ORM exactly as documented in the database section:

```dart
import 'package:vania/database.dart';

// Query builder
final users = await DB
    .table('users')
    .where('active', '=', true)
    .orderBy('created_at', 'desc')
    .limit(10)
    .get();

// Models
final user = await User().query.where('email', '=', 'a@b.com').first();

// Migrations
class CreateUsersTable extends Migration {
  @override
  Future<void> up() async {
    await create('users', (Schema schema) {
      schema.id();
      schema.string('email').unique();
      schema.timeStamps();
    }, true);
  }

  @override
  Future<void> down() async => drop('users');
}
```

See:

- [Query Builder](../database/query-builder.md)
- [Models](../database/models.md)
- [Relationships](../database/relationships.md)
- [Migrations](../database/migrations.md)
- [Seeders & Factories](../database/seeders.md)

## MySQL-specific notes

- **Engine and charset.** New tables default to InnoDB with `utf8mb4`, which is what you want for full Unicode (including emoji). If you need a different engine, set it on the table definition in your migration.
- **`AUTO_INCREMENT` ids.** `schema.id()` produces an unsigned `BIGINT` primary key with `AUTO_INCREMENT`.
- **Booleans.** MySQL has no native boolean; it stores them as `TINYINT(1)`. The driver reads `1`/`0` back as Dart `true`/`false` for boolean columns.
- **Upserts.** `ConflictAction` maps to `ON DUPLICATE KEY UPDATE`.
- **MariaDB.** MariaDB speaks the same protocol and works with this driver. Very new MySQL 8 features that MariaDB lacks are the only thing to watch for.

## Connection pooling

Connections are pooled and reused across requests. You do not open or close them by hand — the `DatabaseServiceProvider` manages the pool for the lifetime of the server.

## Troubleshooting

- **`Access denied for user`** — the credentials in `.env` do not match the database user. Confirm with `mysql -u <user> -p`.
- **`Unknown database`** — create the database first: `CREATE DATABASE my_app;`. The driver connects to an existing database; it does not create one for you.
- **`Can't connect to MySQL server`** — the server is not reachable at `DB_HOST:DB_PORT`. If you are running MySQL in Docker, make sure the port is published (`-p 3306:3306`).

## See also

- [Getting Started with Database](../database/getting-started.md)
- [PostgreSQL Driver](postgresql.md)
- [MongoDB Driver](mongodb.md)
