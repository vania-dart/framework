import 'package:eloquent/eloquent.dart';
import 'package:vania/vania.dart';

class Model {
  String? _table;
  Future<void> _reconnect() async {
    await connection?.reconnectIfMissingConnection();
    /* if (Utils.is_null(connection!.getPdo()) || Utils.is_null(connection!.getReadPdo())) {
      DatabaseClient().setup();
    }*/
  }

  void table(String table) {
    _table = table;
  }

  QueryBuilder query() {
    try {
      _reconnect();
      if (connection == null) {
        abort(500, 'Database connection error');
      }
      return connection!.table(_table!);
    } on InvalidArgumentException catch (e) {
      Logger.log(e.cause.toString(), type: Logger.ERROR);
      abort(500, e.cause.toString());
      rethrow;
    }
  }
}
