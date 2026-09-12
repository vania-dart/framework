/// MongoDB mirror of the SQL contract-compliance suites.
///
/// Mongo ships its own concrete `MongoQueryBuilderImpl` (document
/// backend, not SQL), but the app-visible surface — `Model`, `DB`,
/// `PaginatedResult`, `DatabaseConnectionFactory`, `DBConfig` — comes
/// from `package:vania/database.dart` and must be visible under the
/// same names when the app imports `package:vania_mongodb/vania_mongodb.dart`.
library;

// The compliance checks read `getTable` from outside the class on purpose.
// ignore_for_file: invalid_use_of_protected_member
import 'package:test/test.dart';
import 'package:vania/database.dart' as core;
import 'package:vania_mongodb/vania_mongodb.dart';

class ContractUser extends Model {
  @override
  List<String> get guarded => ['_id'];
}

void main() {
  group('vania_mongodb / contract compliance', () {
    test('re-exports core types under identical names', () {
      expect(core.DatabaseConnectionFactory, same(DatabaseConnectionFactory));
      expect(<Model>[], isA<List<core.Model>>());
      expect(<DBConfig>[], isA<List<core.DBConfig>>());
      expect(<DatabaseConnection>[], isA<List<core.DatabaseConnection>>());
      expect(<PaginatedResult>[], isA<List<core.PaginatedResult>>());
    });

    test('Model subclasses hosted in the driver see core Model', () {
      final user = ContractUser();
      expect(user, isA<core.Model>());
      // Same table-naming rule as the SQL drivers — swapping drivers
      // must not rename the underlying collection.
      expect(user.getTable, 'contract_users');
    });

    test('driver registration lands on the shared factory', () {
      DatabaseConnectionFactory.debugClear();
      registerMongoDbDriver();
      expect(DatabaseConnectionFactory.isRegistered('mongodb'), isTrue);
      expect(DatabaseConnectionFactory.isRegistered('mongo'), isTrue);
    });
  });
}
