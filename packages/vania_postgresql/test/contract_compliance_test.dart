/// Postgres mirror of the vania_mysql contract-compliance suite.
/// Any drift between the two would mean swapping drivers requires app
/// code changes — the anti-goal of this whole refactor.
library;

// The compliance checks read `getTable` from outside the class on purpose.
// ignore_for_file: invalid_use_of_protected_member
import 'package:test/test.dart';
import 'package:vania/database.dart' as core;
import 'package:vania_postgresql/vania_postgresql.dart';

class ContractUser extends Model {
  @override
  List<String> get guarded => ['id'];
}

void main() {
  group('vania_postgresql / contract compliance', () {
    test('re-exports core types under identical names', () {
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
      expect(user.getTable, 'contract_users');
    });

    test('DB top-level getter returns a QueryBuilder', () {
      expect(DB, isA<QueryBuilder>());
    });

    test('driver registration lands on the shared factory', () {
      DatabaseConnectionFactory.debugClear();
      registerPostgreSqlDriver();
      expect(DatabaseConnectionFactory.isRegistered('pgsql'), isTrue);
      expect(DatabaseConnectionFactory.isRegistered('postgres'), isTrue);
      expect(DatabaseConnectionFactory.isRegistered('postgresql'), isTrue);
    });
  });
}
