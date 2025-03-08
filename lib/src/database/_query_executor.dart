import '../performance/_task_manager.dart';
import '../contract/database/_connectors/_database_connection.dart';
import '../exception/invalid_argument_exception.dart';

class QueryExecutor {
  final TaskManager _taskManager = TaskManager();
  final DatabaseConnection _connection;

  QueryExecutor(this._connection);

  Future<List<Map<String, dynamic>>> executeHeavySelect(
    String query,
    Map<String, dynamic> bindings, {
    Duration? timeout,
  }) async {
    return await _taskManager.runInIsolate(
      () => _connection.select(query, bindings),
      taskId: 'heavy_select_${DateTime.now().millisecondsSinceEpoch}',
      timeout: timeout,
    );
  }

  Future<void> executeHeavyBatchOperation(
    List<String> queries,
    List<Map<String, dynamic>> bindingsList, {
    Duration? timeout,
  }) async {
    if (queries.length != bindingsList.length) {
      throw InvalidArgumentException('Queries and bindings count mismatch');
    }

    await _taskManager.runInIsolate(() async {
      for (var i = 0; i < queries.length; i++) {
        await _connection.execute(queries[i], bindingsList[i]);
      }
    },
        taskId: 'batch_operation_${DateTime.now().millisecondsSinceEpoch}',
        timeout: timeout);
  }

  Future<List<Map<String, dynamic>>> executeDataExport(
    String query,
    Map<String, dynamic> bindings, {
    Duration? timeout,
  }) async {
    return await _taskManager.runInIsolate(
      () => _connection.select(query, bindings),
      taskId: 'data_export_${DateTime.now().millisecondsSinceEpoch}',
      timeout: timeout ?? Duration(minutes: 30),
    );
  }

  Future<void> executeDataImport(
    String table,
    List<Map<String, dynamic>> records, {
    Duration? timeout,
    int batchSize = 1000,
  }) async {
    await _taskManager.runInIsolate(() async {
      for (var i = 0; i < records.length; i += batchSize) {
        final batch = records.skip(i).take(batchSize).toList();
        final values = batch
            .map((r) => '(${r.values.map((v) => '?').join(', ')})')
            .join(', ');
        final query =
            'INSERT INTO $table (${batch[0].keys.join(', ')}) VALUES $values';
        final flatBindings = batch.expand((r) => r.values).toList();
        await _connection.execute(query, {'values': flatBindings});
      }
    },
        taskId: 'data_import_${DateTime.now().millisecondsSinceEpoch}',
        timeout: timeout ?? Duration(hours: 1));
  }
}
