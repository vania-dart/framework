---
sidebar_position: 1
---

# Database — Getting Started

Vania's database layer follows a driver-agnostic architecture. The core framework defines the query builder, ORM, migrations, and seeders. Separate driver packages (`vania_mysql`, `vania_postgresql`, `vania_mongodb`) provide the actual database connections. Your application code never imports a driver directly — you swap databases by changing one line of configuration.

## Installation

Add the core framework and your chosen driver to `pubspec.yaml`:

```yaml
dependencies:
  vania: ^2.0.0
  vania_mysql: ^1.0.0
```

Or for PostgreSQL:

```yaml
dependencies:
  vania: ^2.0.0
  vania_postgresql: ^1.0.0
```

Or for MongoDB:

```yaml
dependencies:
  vania: ^2.0.0
  vania_mongodb: ^1.0.0
```

## Driver Registration

In your `bin/server.dart`, register the driver before initializing the application:

```dart
import 'package:vania/vania.dart';
import 'package:vania_mysql/vania_mysql.dart';
import 'package:my_app/config/app.dart';

void main() async {
  registerMySqlDriver();
  await Application().initialize(config: config);
}
```

| Driver | Registration Function | Aliases |
|--------|----------------------|---------|
| MySQL | `registerMySqlDriver()` | `mysql`, `mariadb` |
| PostgreSQL | `registerPostgreSqlDriver()` | `pgsql`, `postgres`, `postgresql` |
| MongoDB | `registerMongoDbDriver()` | `mongodb`, `mongo` |

## Configuration

Add the database config to `lib/config/app.dart`:

```dart
import 'package:vania/database.dart';

Map<String, dynamic> config = {
  // ... other config
  'database': {
    'default': env('DB_CONNECTION', 'mysql'),
    'connections': {
      'mysql': DBConfig(
        driver: 'mysql',
        host: env('DB_HOST', 'localhost'),
        port: env<int>('DB_PORT', 3306),
        database: env('DB_DATABASE', 'my_app'),
        username: env('DB_USERNAME', 'root'),
        password: env('DB_PASSWORD', ''),
        sslMode: env<bool>('DB_SSL_MODE', false),
        pool: env<bool>('DB_POOL', false),
        poolSize: env<int>('DB_POOL_SIZE', 2),
      ),
    },
  },
  'providers': [
    RouteServiceProvider(),
    DatabaseServiceProvider(),
  ],
};
```

Set your credentials in `.env`:

```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=my_app
DB_USERNAME=root
DB_PASSWORD=secret
```

## DBConfig Options

| Field | Default | Description |
|-------|---------|-------------|
| `driver` | — | Driver name (`mysql`, `pgsql`, `mongodb`) |
| `host` | `localhost` | Database host |
| `port` | `3306` | Database port |
| `username` | `root` | Connection username |
| `password` | `''` | Connection password |
| `database` | `vania` | Database name |
| `sslMode` | `false` | Enable TLS (boolean) |
| `pool` | `false` | Enable connection pooling |
| `poolSize` | `2` | Number of pool connections |
| `schema` | — | PostgreSQL schema |
| `timezone` | — | Connection timezone |

## Multiple Connections

Define additional named connections:

```dart
'database': {
  'default': 'mysql',
  'connections': {
    'mysql': DBConfig(driver: 'mysql', ...),
    'analytics': DBConfig(driver: 'pgsql', ...),
  },
},
```

Switch connections at query time:

```dart
var results = await DB.connection('analytics').table('events').get();
```

Or in a model:

```dart
var users = await User().query.connection('analytics').get();
```

## Running Queries

Once configured, use the `DB` getter for raw queries:

```dart
import 'package:vania/database.dart';

var users = await DB.table('users').get();
var user = await DB.table('users').where('id', '=', 1).first();
```

Or use the ORM:

```dart
var users = await User().query.get();
var user = await User().query.find(1);
```

See [Query Builder](query-builder.md) and [Models](models.md) for the full API.

## Connection Monitoring

Vania monitors database performance automatically. Slow queries (>100ms) and high connection usage (>80%) generate alerts:

```dart
var stats = ConnectionManager().getPerformanceStats();
var alerts = ConnectionManager().alerts; // Stream<DatabaseAlert>
```

## Isolate-Safe Queries

Run a query in a separate Dart isolate to avoid blocking the event loop:

```dart
var result = await IsolateDB.run(
  (db) => db.table('large_table').where('status', '=', 'pending').get(),
  dbConfig,
);
```

## Transactions

```dart
await DB.transaction((db) async {
  await db.table('accounts').where('id', '=', 1).decrement('balance', 100);
  await db.table('accounts').where('id', '=', 2).increment('balance', 100);
  return true; // commit
});
```

Return `false` or throw to roll back.
