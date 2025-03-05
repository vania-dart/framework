import '_connection_pool.dart';
import '../_database_utils/_db_config.dart';

class PoolManager {
  final Map<String, ConnectionPool> _pools = {};
  ConnectionPool getPool(DBConfig config) {
    final key = "${config.driver}-${config.host}-${config.database}";
    if (!_pools.containsKey(key)) {
      _pools[key] = ConnectionPool(config: config);
    }
    return _pools[key]!;
  }

  Future<void> closeAllPools() async {
    for (final pool in _pools.values) {
      await pool.closeAll();
    }
    _pools.clear();
  }
}
