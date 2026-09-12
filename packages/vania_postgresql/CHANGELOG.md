## 1.0.0

First release as a thin driver. The ORM, query builder, and migration system it
used to carry now live in `vania` 2.0.0, so this package is just the PostgreSQL
bridge.

- Requires `vania` 2.0.0.
- `registerPostgreSqlDriver()` registers a `PostgresConnector` with core's
  shared connection factory. That call in `main.dart` is the only place your
  app names PostgreSQL.
- Everything else — `Model`, `DB`, relations, `Migration`, `Schema` — is
  imported from `package:vania/database.dart`.
- `export 'package:vania/database.dart'` is kept, so existing
  `import 'package:vania_postgresql/vania_postgresql.dart' show Model, DB;`
  still resolves.
- Contract-compliance tests assert this package exposes the same symbols, under
  the same names, as the MySQL and MongoDB drivers.

### Upgrading from 0.x

Replace database imports across your app with
`import 'package:vania/database.dart';` and keep the `vania_postgresql` import only
in `main.dart`, next to `registerPostgreSqlDriver()`.
