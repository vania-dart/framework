import 'package:test/test.dart';
import 'package:vania_postgresql/vania_postgresql.dart';

void main() {
  test('registers the PostgreSQL driver and aliases', () {
    registerPostgreSqlDriver();

    expect(DatabaseConnectionFactory.isRegistered('pgsql'), isTrue);
    expect(DatabaseConnectionFactory.isRegistered('postgres'), isTrue);
    expect(DatabaseConnectionFactory.isRegistered('postgresql'), isTrue);
  });
}
