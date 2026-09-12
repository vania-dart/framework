/// The MongoDB driver for the Vania framework.
///
/// New-project pattern:
/// ```dart
/// // main.dart
/// import 'package:vania_mongodb/vania_mongodb.dart';
/// void main() async {
///   registerMongoDbDriver();
///   await Application.initialize(...);
/// }
/// ```
///
/// Every other file — models, controllers, migrations — imports only
/// `package:vania/database.dart` (or the top-level `package:vania/vania.dart`)
/// and never mentions the driver again. Switching to MySQL/Postgres is
/// a `pubspec.yaml` + one-line change.
///
/// Notes on API portability against MongoDB:
///
///   * The portable `QueryBuilder` surface (from
///     `package:vania/database.dart`) is honored by MySQL, PostgreSQL,
///     and MongoDB identically for the parts document stores support:
///     `select`, `where*`, `find`, `first`, `get`, `insert`, `update`,
///     `delete`, `paginate`, aggregations, chunking, etc.
///   * SQL-only ops (`join`/`union`/`cte`/`window*`/raw SQL) are
///     no-ops today for backward compatibility. Consider casting to
///     `MongoQueryBuilderImpl` and using the document escape hatches
///     (`rawWhere(selector)`, `toSelector()`) when you need Mongo
///     semantics that don't fit the portable shape.
library;

import 'package:vania/database.dart' show DatabaseConnectionFactory;
import 'package:vania/service_provider.dart';
import 'src/mongo_connector.dart';

export 'package:vania/database.dart';

// Mongo-specific escape hatches for advanced users.
export 'src/database/query_builder/mongo_query_builder_impl.dart';
export 'src/mongo_config.dart';
export 'src/mongo_connection.dart';
export 'src/mongo_connector.dart';
export 'src/mongo_db.dart';
export 'src/mongo_query_builder.dart';
export 'src/mongo_service_provider.dart';

// Backward-compat re-exports so imports of
// `package:vania_mongodb/vania_mongodb.dart show Model, PersonalAccessToken`
// keep resolving. Model/PersonalAccessToken come through `package:vania/database.dart`
// via the re-export above.
export 'src/authentication/orm_personal_access_token_store.dart';
export 'src/authentication/model/personal_access_token.dart';

/// Registers the MongoDB driver + `mongo` alias with the shared
/// [DatabaseConnectionFactory]. Call once at app boot.
void registerMongoDbDriver() {
  DatabaseConnectionFactory.register(
    'mongodb',
    MongoConnector.new,
    aliases: const ['mongo'],
  );
}

/// A [ServiceProvider] that only registers the driver, without wiring
/// the [MongoConnection] singleton. Use this when a
/// [DatabaseServiceProvider] elsewhere in the app handles boot.
class MongoDBDriverServiceProvider extends ServiceProvider {
  const MongoDBDriverServiceProvider();

  @override
  Future<void> register() async {
    registerMongoDbDriver();
  }

  @override
  Future<void> boot() async {}
}

/// Kept as a legacy alias for existing apps that reference
/// `MongoDBOrmServiceProvider` in their provider list. New code should
/// use [MongoDBServiceProvider] from `src/mongo_service_provider.dart`
/// or [MongoDBDriverServiceProvider] above.
class MongoDBOrmServiceProvider extends MongoDBDriverServiceProvider {
  const MongoDBOrmServiceProvider();
}
