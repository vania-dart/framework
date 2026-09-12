---
sidebar_position: 3
---

# PostgreSQL Driver (vania_postgresql)

`vania_postgresql` is the PostgreSQL driver for Vania's ORM. Like the MySQL driver, it is a thin bridge: it supplies a real PostgreSQL connection to the shared database layer in the core package, and everything in the [Database & ORM](../database/getting-started.md) section works on top of it without change.

If you have read the MySQL driver page, this one will feel familiar — the shape is identical by design. The only differences are the connection settings, the registration call, and a handful of PostgreSQL-specific behaviours noted at the bottom.

## Installation

```yaml
dependencies:
  vania: ^2.0.0
  vania_postgresql: ^1.0.0
```

```bash
dart pub get
```

## Configuration

`.env`:

```env
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=my_app
DB_USERNAME=postgres
DB_PASSWORD=secret
```

`config/app.dart`:

```dart
Map<String, dynamic> config = {
  'database': {
    'default': env('DB_CONNECTION', 'pgsql'),
    'connections': {
      'pgsql': {
        'driver': 'pgsql',
        'host': env('DB_HOST', 'localhost'),
        'port': env<int>('DB_PORT', 5432),
        'database': env('DB_DATABASE', 'my_app'),
        'username': env('DB_USERNAME', 'postgres'),
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

Call `registerPostgreSqlDriver()` in `bin/server.dart`, before `Application().initialize`:

```dart
import 'package:vania/vania.dart';
import 'package:vania_postgresql/vania_postgresql.dart';
import 'package:my_app/config/app.dart';

void main() async {
  registerPostgreSqlDriver();

  await Application().initialize(config: config);
}
```

That single call is the only PostgreSQL-specific line in your codebase. Your models, migrations, and queries stay driver-agnostic because they import `package:vania/database.dart`, not the driver.

## What you get

The same ORM surface as every other SQL driver:

```dart
import 'package:vania/database.dart';

final rows = await DB
    .table('orders')
    .where('status', '=', 'paid')
    .whereBetween('total_cents', [1000, 50000])
    .get();
```

See [Query Builder](../database/query-builder.md), [Models](../database/models.md), [Relationships](../database/relationships.md), [Migrations](../database/migrations.md), and [Seeders & Factories](../database/seeders.md).

## PostgreSQL-specific notes

- **Placeholders.** PostgreSQL uses `$1, $2, …` positional parameters instead of MySQL's `?`. The query builder handles this for you — you write the same Dart either way. This is one of the reasons the driver split exists.
- **Serial ids.** `schema.id()` maps to `BIGSERIAL PRIMARY KEY`.
- **Real booleans.** PostgreSQL has a native `boolean` type, so boolean columns round-trip as Dart `bool` directly.
- **Case sensitivity.** Unquoted identifiers fold to lower case. Keep your table and column names lower snake_case (the ORM's default) and you never have to think about it.
- **`RETURNING`.** Inserts use `RETURNING id` to get the new primary key back in a single round trip.
- **Upserts.** `ConflictAction` maps to `ON CONFLICT ... DO UPDATE`.
- **JSON.** Use `json`/`jsonb` columns for structured data; the driver passes values through as encoded JSON.

## Troubleshooting

- **`password authentication failed`** — the role/password pair is wrong. Test with `psql -U <user> -d my_app`.
- **`database "my_app" does not exist`** — create it first: `createdb my_app` (or `CREATE DATABASE my_app;`).
- **`Connection refused`** — the server is not listening on `DB_HOST:DB_PORT`. In Docker, publish the port (`-p 5432:5432`) and set `POSTGRES_PASSWORD`.
- **SSL required** — managed providers (RDS, Cloud SQL, Supabase) often require TLS. Point `DB_HOST` at the provider's host and enable SSL in the connection settings per your provider's guidance.

## See also

- [Getting Started with Database](../database/getting-started.md)
- [MySQL Driver](mysql.md)
- [MongoDB Driver](mongodb.md)
