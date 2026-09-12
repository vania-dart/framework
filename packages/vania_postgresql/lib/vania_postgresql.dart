/// The PostgreSQL driver for the Vania framework.
///
/// This package ships ONE thing — the PostgreSQL `DatabaseConnection`
/// implementation. All of the query-builder, ORM, migration, seeder,
/// and validation surface lives in `package:vania/database.dart` and
/// is re-exported here for backwards compatibility so existing apps
/// that import `package:vania_postgresql/vania_postgresql.dart` keep
/// working without a change.
///
/// The intended new-project pattern:
/// ```dart
/// // main.dart
/// import 'package:vania_postgresql/vania_postgresql.dart';
/// void main() async {
///   registerPostgreSqlDriver();
///   await Application.initialize(...);
/// }
///
/// // Every other file — models, controllers, migrations — imports
/// // only `package:vania/database.dart` and never mentions the
/// // driver again. Switching to MySQL is a pubspec + one-line change.
/// ```
library;

import 'package:vania/database.dart'
    show DatabaseConnectionFactory, DatabaseServiceProvider;
import 'package:vania/service_provider.dart';
import 'src/postgresql_connector.dart';

export 'package:vania/database.dart';
export 'src/postgresql_connector.dart';

/// Registers the PostgreSQL driver + `postgres`/`postgresql` aliases
/// with the shared [DatabaseConnectionFactory]. Call once at app boot.
void registerPostgreSqlDriver() {
  DatabaseConnectionFactory.register(
    'pgsql',
    PostgresConnector.new,
    aliases: const ['postgres', 'postgresql'],
  );
}

/// A [ServiceProvider] that only registers the driver, without the full
/// `DatabaseServiceProvider` boot cycle.
class PostgreSqlDriverServiceProvider extends ServiceProvider {
  const PostgreSqlDriverServiceProvider();

  @override
  Future<void> register() async {
    registerPostgreSqlDriver();
  }

  @override
  Future<void> boot() async {}
}

/// A [DatabaseServiceProvider] pre-wired to register the PostgreSQL
/// driver.
class PostgreSqlServiceProvider extends DatabaseServiceProvider {
  const PostgreSqlServiceProvider();

  @override
  Future<void> register() async {
    registerPostgreSqlDriver();
    await super.register();
  }
}
