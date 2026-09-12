# Vania MongoDB

**The MongoDB driver for Vania — the same ORM you already know, backed by a document database.**

`vania_mongodb` lets Vania talk to MongoDB. It follows the same register-once-then-forget pattern as the SQL drivers, but because a document store is genuinely a different kind of database, this driver carries its own query builder and a couple of escape hatches for the things only Mongo can do.

The upside: if you stick to the portable parts of the ORM — `where`, `find`, `first`, `get`, `insert`, `update`, `delete`, `paginate`, aggregations — your models and controllers look identical to what they'd be on MySQL or PostgreSQL. You only reach for Mongo-specific code when you actually need Mongo-specific behaviour.

## Install

```yaml
dependencies:
  vania: ^2.0.0
  vania_mongodb: ^1.0.0
```

## Register the driver

```dart
import 'package:vania/vania.dart';
import 'package:vania_mongodb/vania_mongodb.dart';
import 'package:my_app/config/app.dart';

void main() async {
  registerMongoDbDriver();

  await Application().initialize(config: config);
}
```

Registered names: `mongodb`, `mongo`.

## Configure the connection

Give a full URI, or the parts and let the driver assemble it:

```env
DB_CONNECTION=mongodb
DB_HOST=127.0.0.1
DB_PORT=27017
DB_DATABASE=my_app
# or a full string for Atlas / SRV:
# DB_URI=mongodb+srv://user:pass@cluster0.mongodb.net/my_app
```

## Use the ORM

```dart
import 'package:vania/database.dart';

// A "table" is a collection here
final active = await DB.table('users').where('active', '=', true).get();
await DB.table('users').insert({'email': 'a@b.com', 'active': true});
```

## When you need real Mongo

SQL-only operations (`join`, `union`, CTEs, raw SQL) are no-ops on a document store. For BSON selectors and aggregation, cast to the Mongo builder and use its native methods:

```dart
import 'package:vania_mongodb/vania_mongodb.dart';

final builder = DB.table('users') as MongoQueryBuilderImpl;
final results = await builder.rawWhere({'tags': {r'$in': ['dart', 'backend']}}).get();
```

## Good to know

- Documents use an `_id` (usually an `ObjectId`), generated on insert if you don't provide one.
- Migrations focus on collections and indexes; column-type calls that don't apply are simply ignored.
- Ships a Mongo-backed personal access token store, so `vania_auth` works without a SQL database.

## Links

- Documentation: [vdart.dev/docs](https://vdart.dev/docs/intro)
- Source & issues: [github.com/vania-dart/framework](https://github.com/vania-dart/framework)

## License

MIT
