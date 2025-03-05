import '../../contract/database/_connectors/_database_connection.dart';

class Transaction {
  final DatabaseConnection connection;
  bool _active = false;

  Transaction(this.connection);

  Future<bool> begin() async {
    final result = await connection.execute("BEGIN;");
    if (result != false) {
      _active = true;
      return true;
    }
    return false;
  }

  Future<bool> commit() async {
    if (!_active) return false;
    final result = await connection.execute("COMMIT;");
    if (result != false) {
      _active = false;
      return true;
    }
    return false;
  }

  Future<bool> rollback() async {
    if (!_active) return false;
    final result = await connection.execute("ROLLBACK;");
    if (result != false) {
      _active = false;
      return true;
    }
    return false;
  }
}
