## 1.0.0

First release on the shared driver contract. MongoDB now goes through the same
`DatabaseConnectionFactory` as the SQL drivers instead of its own singleton.

- Requires `vania` 2.0.0.
- `registerMongoDbDriver()` registers a `MongoConnector`; `Model`, relations,
  and `PaginatedResult` come from `package:vania/database.dart`.
- **Migrations now work on MongoDB.** Core's `MongoAdapter` renders collection
  commands and `MongoConnector` dispatches them to `mongo_dart`, so the same
  migration file runs on MySQL, PostgreSQL, SQLite, and MongoDB.
- `MongoQueryBuilderImpl` and its local contract stay in this package on
  purpose: BSON selectors and aggregation pipelines do not map onto the SQL
  query builder.
- Mongo-specific settings live in `MongoConfig` here, not in core's shared
  `DBConfig`.
- Contract-compliance tests assert this package exposes the same symbols, under
  the same names, as the MySQL and PostgreSQL drivers.
