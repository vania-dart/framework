/// Proves the vania_mysql driver package exposes the shared
/// `QueryBuilder` + `Model` + `Migration` + `Schema` + `DB` surface
/// through its own top-level library, so an app can write:
///
/// ```dart
/// import 'package:vania_mysql/vania_mysql.dart';
/// class User extends Model { ... }
/// ```
///
/// and get identical types to what it would get by importing
/// `package:vania/database.dart` directly. Swapping the driver package
/// leaves application code untouched — that is the whole point of the
/// contract-in-core refactor.
///
/// The test intentionally does NOT open a real MySQL connection. It
/// exercises symbol visibility + basic contract identity, which is
/// exactly what a contract-compliance suite is for.
library;

// The compliance checks read `getTable` from outside the class on purpose.
// ignore_for_file: invalid_use_of_protected_member
import 'package:test/test.dart';
import 'package:vania/database.dart' as core;
import 'package:vania_mysql/vania_mysql.dart';

class ContractUser extends Model {
  @override
  List<String> get guarded => ['id'];
}

void main() {
  group('vania_mysql / contract compliance', () {
    test('re-exports core types under identical names', () {
      // Every symbol below is used only via its type — a name mismatch
      // or an accidentally-hidden export would fail compilation, which
      // is exactly the guarantee we're after.
      expect(core.DatabaseConnectionFactory, same(DatabaseConnectionFactory));
      expect(<QueryBuilder>[], isA<List<core.QueryBuilder>>());
      expect(<Model>[], isA<List<core.Model>>());
      expect(<Migration>[], isA<List<core.Migration>>());
      expect(<Schema>[], isA<List<core.Schema>>());
      expect(<DBConfig>[], isA<List<core.DBConfig>>());
      expect(<DatabaseConnection>[], isA<List<core.DatabaseConnection>>());
      expect(<PaginatedResult>[], isA<List<core.PaginatedResult>>());
      expect(<RawExpression>[], isA<List<core.RawExpression>>());
    });

    test('Model subclasses hosted in the driver see core Model', () {
      final user = ContractUser();
      expect(user, isA<core.Model>());
      // Snake-case + pluralization is contract behavior every driver
      // must honor identically.
      expect(user.getTable, 'contract_users');
    });

    test('DB top-level getter returns a QueryBuilder', () {
      expect(DB, isA<QueryBuilder>());
    });

    test('driver registration lands on the shared factory', () {
      DatabaseConnectionFactory.debugClear();
      registerMySqlDriver();
      expect(DatabaseConnectionFactory.isRegistered('mysql'), isTrue);
      expect(DatabaseConnectionFactory.isRegistered('mariadb'), isTrue);
    });
  });
}
