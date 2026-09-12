/// The MySQL driver for the Vania framework.
///
/// This package ships ONE thing — the MySQL `DatabaseConnection`
/// implementation. All of the query-builder, ORM, migration, seeder,
/// and validation surface lives in `package:vania/database.dart` and
/// is re-exported here for backwards compatibility so existing apps
/// that import `package:vania_mysql/vania_mysql.dart` keep working
/// without a change.
///
/// The intended new-project pattern:
/// ```dart
/// // main.dart
/// import 'package:vania_mysql/vania_mysql.dart';
/// void main() async {
///   registerMySqlDriver();
///   await Application.initialize(...);
/// }
///
/// // Every other file — models, controllers, migrations — imports
/// // only `package:vania/database.dart` (or the top-level
/// // `package:vania/vania.dart`) and never mentions the driver again.
/// ```
library;

import 'package:vania/database.dart'
    show DatabaseConnectionFactory, DatabaseServiceProvider;
import 'package:vania/service_provider.dart';
import 'src/mysql_connector.dart';

export 'package:vania/database.dart';
export 'src/mysql_connector.dart';

/// Registers the MySQL driver + `mariadb` alias with the shared
/// [DatabaseConnectionFactory]. Call once at app boot.
void registerMySqlDriver() {
  DatabaseConnectionFactory.register(
    'mysql',
    MySqlConnector.new,
    aliases: const ['mariadb'],
  );
}

/// A [ServiceProvider] that only registers the driver, without the full
/// `DatabaseServiceProvider` boot cycle. Useful when app boot handles
/// the boot cycle itself.
class MySqlDriverServiceProvider extends ServiceProvider {
  const MySqlDriverServiceProvider();

  @override
  Future<void> register() async {
    registerMySqlDriver();
  }

  @override
  Future<void> boot() async {}
}

/// A [DatabaseServiceProvider] pre-wired to register the MySQL driver.
/// Add this to your `ServiceProvider` list to boot the framework
/// against a MySQL connection with no extra plumbing.
class MySqlServiceProvider extends DatabaseServiceProvider {
  const MySqlServiceProvider();

  @override
  Future<void> register() async {
    registerMySqlDriver();
    await super.register();
  }
}
