part of 'legacy_query_builder.dart';

enum ConflictAction { update, ignore, replace, delete }

abstract class BulkOperationsBuilder {
  Future<bool> merge(
    List<Map<String, dynamic>> sourceData, {
    required List<String> matchOn,
    ConflictAction whenMatched = ConflictAction.update,
    ConflictAction whenNotMatched = ConflictAction.ignore,
    ConflictAction? whenNotMatchedBySource,
    List<String>? updateColumns,
    List<String>? insertColumns,
    Map<String, dynamic>? additionalValues,
  });

  Future<bool> bulkInsert(
    List<Map<String, dynamic>> data, {
    ConflictAction conflictAction = ConflictAction.ignore,
    List<String>? conflictColumns,
    List<String>? updateColumns,
    int batchSize = 1000,
    bool returnIds = false,
  });

  Future<bool> bulkUpdate(
    List<Map<String, dynamic>> updates, {
    required String matchColumn,
    List<String>? updateColumns,
    int batchSize = 500,
    Map<String, dynamic>? additionalValues,
  });

  Future<bool> bulkDelete({
    String? column,
    List<dynamic>? values,
    int batchSize = 1000,
  });

  Future<bool> bulkDeleteWhere(
    List<Map<String, dynamic>> conditions, {
    int batchSize = 500,
  });

  Future<void> batchProcess({
    required int batchSize,
    required Future<void> Function(
      List<Map<String, dynamic>> batch,
      int batchNumber,
    )
    processor,
    List<String> columns = const ['*'],
  });

  Future<void> chunkedProcess({
    required int chunkSize,
    required Future<List<Map<String, dynamic>>> Function(
      List<Map<String, dynamic>> chunk,
    )
    processor,
    String? destination,
    List<String> columns = const ['*'],
  });

  Future<bool> parallelBulkInsert(
    List<Map<String, dynamic>> data, {
    int parallelism = 2,
    int batchSize = 1000,
    ConflictAction conflictAction = ConflictAction.ignore,
    List<String>? conflictColumns,
  });

  Future<bool> transactionalBulkOperation(Future<bool> Function() operations);
}
