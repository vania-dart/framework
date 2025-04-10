import 'package:vania/vania.dart';

class Model {
  String? _table;
  String? _connection;

  void table(String table) {
    _table = table;
  }

  void connection(String connection) {
    _connection = connection;
  }

  QueryBuilder query() {
    if (_table == null) {
      abort(500, 'Table name not specified');
    }
    return DB.connection(_connection).from(_table!);
  }
}
