import 'package:test/test.dart';
import 'package:vania_mysql/vania_mysql.dart';

void main() {
  test('registers the MySQL driver and aliases', () {
    registerMySqlDriver();

    expect(DatabaseConnectionFactory.isRegistered('mysql'), isTrue);
    expect(DatabaseConnectionFactory.isRegistered('mariadb'), isTrue);
  });
}
