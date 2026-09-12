---
sidebar_position: 4
---

# MongoDB Driver (vania_mongodb)

`vania_mongodb` lets Vania's ORM talk to MongoDB, a document (NoSQL) database. It follows the same driver pattern as the SQL drivers — register it once at boot, then work through `package:vania/database.dart` — but because a document store is a genuinely different kind of database, this driver carries its own query builder implementation and a couple of escape hatches for Mongo-only features.

If you only need the portable parts of the ORM (`where`, `find`, `first`, `get`, `insert`, `update`, `delete`, `paginate`, aggregations, chunking), your models and controllers look the same as they would on MySQL or PostgreSQL. The differences show up only when you reach for something specific to Mongo.

## Installation

```yaml
dependencies:
  vania: ^2.0.0
  vania_mongodb: ^1.0.0
```

```bash
dart pub get
```

## Configuration

MongoDB is addressed by a connection URI. You can give the URI directly, or give host/port/credentials and let the driver assemble it.

`.env`:

```env
DB_CONNECTION=mongodb
DB_HOST=127.0.0.1
DB_PORT=27017
DB_DATABASE=my_app
DB_USERNAME=
DB_PASSWORD=
```

`config/app.dart`:

```dart
Map<String, dynamic> config = {
  'database': {
    'default': env('DB_CONNECTION', 'mongodb'),
    'connections': {
      'mongodb': {
        'driver': 'mongodb',
        // Either give a full URI:
        // 'uri': env('DB_URI', 'mongodb://localhost:27017/my_app'),
        // …or the parts, and the driver builds the URI for you:
        'host': env('DB_HOST', 'localhost'),
        'port': env<int>('DB_PORT', 27017),
        'database': env('DB_DATABASE', 'my_app'),
        'username': env('DB_USERNAME', ''),
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

If your database lives behind an SRV record or a managed cluster (Atlas), set the full connection string via `uri` instead of the host/port pieces:

```dart
'mongodb': {
  'driver': 'mongodb',
  'uri': env('DB_URI', 'mongodb+srv://user:pass@cluster0.mongodb.net/my_app'),
},
```

## Registering the driver

Call `registerMongoDbDriver()` in `bin/server.dart`, before `Application().initialize`:

```dart
import 'package:vania/vania.dart';
import 'package:vania_mongodb/vania_mongodb.dart';
import 'package:my_app/config/app.dart';

void main() async {
  registerMongoDbDriver();

  await Application().initialize(config: config);
}
```

The driver also registers a `mongo` alias, so `DB_CONNECTION=mongo` works too.

## What maps and what doesn't

The portable `QueryBuilder` surface is honoured for everything a document store can reasonably do:

```dart
import 'package:vania/database.dart';

// Reads
final active = await DB
    .table('users')          // a "table" is a collection here
    .where('active', '=', true)
    .orderBy('created_at', 'desc')
    .limit(10)
    .get();

// Writes
await DB.table('users').insert({'email': 'a@b.com', 'active': true});
await DB.table('users').where('id', '=', 1).update({'active': false});
await DB.table('users').where('id', '=', 1).delete();

// Pagination and aggregation work as usual
final page = await DB.table('users').paginate(perPage: 20, page: 1);
```

SQL-only operations have no equivalent in a document store. `join`, `union`, CTEs, window functions, and raw SQL are **no-ops** on this driver (they are accepted but do nothing, so shared code keeps compiling). If you need to model related data, embed it in the document or do the lookup in application code.

## Mongo-specific escape hatches

When you need real Mongo semantics — BSON selectors, aggregation pipelines — cast the builder to `MongoQueryBuilderImpl` (exported by the driver) and use its document-native methods:

```dart
import 'package:vania_mongodb/vania_mongodb.dart';

final builder = DB.table('users') as MongoQueryBuilderImpl;

// A raw BSON selector, exactly as the Mongo shell would take it:
final results = await builder
    .rawWhere({'tags': {r'$in': ['dart', 'backend']}})
    .get();

// Inspect the selector the portable where() calls produced:
final selector = builder.toSelector();
```

Reach for these only when the portable API can't express what you need. Keeping the rest of your code on the portable surface is what lets you move a collection to (or from) SQL later.

## Ids

MongoDB documents use an `_id` field, typically an `ObjectId`. When you insert without specifying an id, Mongo generates one. Reads expose the id so you can address a document by it in later queries.

## Migrations

Mongo is schemaless, so migrations are mostly about creating collections and indexes rather than columns. The [Migrations](../database/migrations.md) API is supported by this driver; column-type calls that don't apply to a document store are ignored, while collection and index operations run against Mongo.

## Authentication support

The driver ships a Mongo-backed personal access token store and token model, so `vania_auth` works against MongoDB without a SQL database:

```dart
import 'package:vania_mongodb/vania_mongodb.dart';
// OrmPersonalAccessTokenStore, PersonalAccessToken (Mongo variants) are exported here.
```

See the [Authentication](auth.md) page for how the token store fits into the auth stack.

## Troubleshooting

- **`MongoDB connection failed`** — the URI is wrong or the server is unreachable. Test with `mongosh "mongodb://localhost:27017/my_app"`.
- **Auth errors on Atlas** — make sure the database user has access to the named database and your current IP is on the cluster's access list.
- **A `join`/raw-SQL call "did nothing"** — that is expected. Those are SQL-only and are no-ops here; use embedding or `rawWhere` instead.

## See also

- [Getting Started with Database](../database/getting-started.md)
- [MySQL Driver](mysql.md)
- [PostgreSQL Driver](postgresql.md)
