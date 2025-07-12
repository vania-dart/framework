import 'dart:async';

import 'package:meta/meta.dart';

import '../../contract/database/query_builder/query_builder.dart'
    show QueryBuilder, ConflictAction;
import '../../exception/invalid_argument_exception.dart';
import '_query_builder_impl.dart';

abstract mixin class BulkOperationsBuilderImpl implements QueryBuilder {
  @protected
  int _paramCounter = 0;

  String _nextParamName() {
    _paramCounter++;
    return 'bulk_p$_paramCounter';
  }

  @override
  Future<bool> merge(
    List<Map<String, dynamic>> sourceData, {
    required List<String> matchOn,
    ConflictAction whenMatched = ConflictAction.update,
    ConflictAction whenNotMatched = ConflictAction.ignore,
    ConflictAction? whenNotMatchedBySource,
    List<String>? updateColumns,
    List<String>? insertColumns,
    Map<String, dynamic>? additionalValues,
  }) async {
    if (sourceData.isEmpty) {
      throw InvalidArgumentException(
          'Source data cannot be empty for merge operation');
    }

    if (matchOn.isEmpty) {
      throw InvalidArgumentException(
          'Match columns cannot be empty for merge operation');
    }

    try {
      final conn = await getConnection();
      final paramBindings = <String, dynamic>{};

      final sourceColumns = sourceData.first.keys.toList();
      final valueGroups = <String>[];

      for (var row in sourceData) {
        final placeholders = sourceColumns.map((column) {
          final paramName = _nextParamName();
          paramBindings[paramName] = row[column];
          return ":$paramName";
        }).join(", ");
        valueGroups.add("($placeholders)");
      }

      final sourceClause =
          "(VALUES ${valueGroups.join(', ')}) AS source(${sourceColumns.join(', ')})";

      final matchConditions =
          matchOn.map((col) => "$getTable.$col = source.$col").join(' AND ');

      String mergeSQL =
          "MERGE INTO $getTable USING $sourceClause ON $matchConditions";

      if (whenMatched == ConflictAction.update) {
        final columnsToUpdate = updateColumns ??
            sourceColumns.where((col) => !matchOn.contains(col)).toList();
        final updateSets =
            columnsToUpdate.map((col) => "$col = source.$col").join(', ');
        mergeSQL += " WHEN MATCHED THEN UPDATE SET $updateSets";
      } else if (whenMatched == ConflictAction.delete) {
        mergeSQL += " WHEN MATCHED THEN DELETE";
      }

      if (whenNotMatched != ConflictAction.ignore) {
        final columnsToInsert = insertColumns ?? sourceColumns;
        final insertValues =
            columnsToInsert.map((col) => "source.$col").join(', ');
        mergeSQL +=
            " WHEN NOT MATCHED THEN INSERT (${columnsToInsert.join(', ')}) VALUES ($insertValues)";
      }

      if (whenNotMatchedBySource == ConflictAction.delete) {
        mergeSQL += " WHEN NOT MATCHED BY SOURCE THEN DELETE";
      }

      await conn.execute(mergeSQL, paramBindings);
      return true;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> bulkInsert(
    List<Map<String, dynamic>> data, {
    ConflictAction conflictAction = ConflictAction.ignore,
    List<String>? conflictColumns,
    List<String>? updateColumns,
    int batchSize = 1000,
    bool returnIds = false,
  }) async {
    if (data.isEmpty) {
      throw InvalidArgumentException(
          'Data cannot be empty for bulk insert operation');
    }

    try {
      final conn = await getConnection();
      for (int i = 0; i < data.length; i += batchSize) {
        final batch = data.skip(i).take(batchSize).toList();
        final paramBindings = <String, dynamic>{};

        final columns = batch.first.keys.toList();
        final valueGroups = <String>[];

        for (var row in batch) {
          final placeholders = columns.map((column) {
            final paramName = _nextParamName();
            paramBindings[paramName] = row[column];
            return ":$paramName";
          }).join(", ");
          valueGroups.add("($placeholders)");
        }

        String sql =
            "INSERT INTO $getTable (${columns.join(', ')}) VALUES ${valueGroups.join(', ')}";

        if (conflictAction == ConflictAction.ignore) {
          sql =
              "INSERT IGNORE INTO $getTable (${columns.join(', ')}) VALUES ${valueGroups.join(', ')}";
        } else if (conflictAction == ConflictAction.update &&
            conflictColumns != null) {
          final updateCols = updateColumns ??
              columns.where((col) => !conflictColumns.contains(col)).toList();
          final updateSets =
              updateCols.map((col) => "$col = VALUES($col)").join(', ');
          sql += " ON DUPLICATE KEY UPDATE $updateSets";
        } else if (conflictAction == ConflictAction.replace) {
          sql =
              "REPLACE INTO $getTable (${columns.join(', ')}) VALUES ${valueGroups.join(', ')}";
        }

        await conn.execute(sql, paramBindings);
      }

      return true;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> bulkUpdate(
    List<Map<String, dynamic>> updates, {
    required String matchColumn,
    List<String>? updateColumns,
    int batchSize = 500,
    Map<String, dynamic>? additionalValues,
  }) async {
    if (updates.isEmpty) {
      throw InvalidArgumentException(
          'Updates cannot be empty for bulk update operation');
    }

    try {
      final conn = await getConnection();

      for (int i = 0; i < updates.length; i += batchSize) {
        final batch = updates.skip(i).take(batchSize).toList();

        final columns = updateColumns ??
            batch.first.keys.where((key) => key != matchColumn).toList();
        final paramBindings = <String, dynamic>{};

        final matchValues = <String>[];
        final caseClauses = <String, List<String>>{};

        for (var column in columns) {
          caseClauses[column] = [];
        }

        for (var row in batch) {
          final matchParamName = _nextParamName();
          paramBindings[matchParamName] = row[matchColumn];
          matchValues.add(":$matchParamName");

          for (var column in columns) {
            final valueParamName = _nextParamName();
            paramBindings[valueParamName] = row[column];
            caseClauses[column]!
                .add("WHEN :$matchParamName THEN :$valueParamName");
          }
        }

        final setClauses = caseClauses.entries.map((entry) {
          final caseStatement =
              "CASE $matchColumn ${entry.value.join(' ')} END";
          return "${entry.key} = $caseStatement";
        }).toList();

        if (additionalValues != null) {
          for (var entry in additionalValues.entries) {
            final paramName = _nextParamName();
            paramBindings[paramName] = entry.value;
            setClauses.add("${entry.key} = :$paramName");
          }
        }

        final sql =
            "UPDATE $getTable SET ${setClauses.join(', ')} WHERE $matchColumn IN (${matchValues.join(', ')})";

        await conn.execute(sql, paramBindings);
      }

      return true;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> bulkDelete({
    String? column,
    List<dynamic>? values,
    int batchSize = 1000,
  }) async {
    if (column == null || values == null || values.isEmpty) {
      throw InvalidArgumentException(
          'Column and values must be provided for bulk delete operation');
    }

    try {
      final conn = await getConnection();

      for (int i = 0; i < values.length; i += batchSize) {
        final batch = values.skip(i).take(batchSize).toList();
        final paramBindings = <String, dynamic>{};

        final placeholders = batch.map((value) {
          final paramName = _nextParamName();
          paramBindings[paramName] = value;
          return ":$paramName";
        }).join(', ');

        final sql = "DELETE FROM $getTable WHERE $column IN ($placeholders)";

        await conn.execute(sql, paramBindings);
      }

      return true;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> bulkDeleteWhere(
    List<Map<String, dynamic>> conditions, {
    int batchSize = 500,
  }) async {
    if (conditions.isEmpty) {
      throw InvalidArgumentException(
          'Conditions cannot be empty for bulk delete operation');
    }

    try {
      final conn = await getConnection();
      for (int i = 0; i < conditions.length; i += batchSize) {
        final batch = conditions.skip(i).take(batchSize).toList();
        final paramBindings = <String, dynamic>{};

        final orConditions = <String>[];

        for (var conditionMap in batch) {
          final andConditions = <String>[];

          for (var entry in conditionMap.entries) {
            final paramName = _nextParamName();
            paramBindings[paramName] = entry.value;
            andConditions.add("${entry.key} = :$paramName");
          }

          orConditions.add("(${andConditions.join(' AND ')})");
        }

        final sql = "DELETE FROM $getTable WHERE ${orConditions.join(' OR ')}";

        await conn.execute(sql, paramBindings);
      }

      return true;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> batchProcess({
    required int batchSize,
    required Future<void> Function(
            List<Map<String, dynamic>> batch, int batchNumber)
        processor,
    List<String> columns = const ['*'],
  }) async {
    int batchNumber = 1;
    int offset = 0;

    while (true) {
      final batchQuery = QueryBuilderImpl()
        ..table(getTable)
        ..select(columns)
        ..limit(batchSize)
        ..offset(offset);

      final batch = await batchQuery.get();

      if (batch.isEmpty) break;

      await processor(batch, batchNumber);

      if (batch.length < batchSize) break;

      offset += batchSize;
      batchNumber++;
    }
  }

  @override
  Future<void> chunkedProcess({
    required int chunkSize,
    required Future<List<Map<String, dynamic>>> Function(
            List<Map<String, dynamic>> chunk)
        processor,
    String? destination,
    List<String> columns = const ['*'],
  }) async {
    int offset = 0;

    while (true) {
      final chunkQuery = QueryBuilderImpl()
        ..table(getTable)
        ..select(columns)
        ..limit(chunkSize)
        ..offset(offset);

      final chunk = await chunkQuery.get();

      if (chunk.isEmpty) break;

      final processedChunk = await processor(chunk);

      if (destination != null && processedChunk.isNotEmpty) {
        final insertQuery = QueryBuilderImpl()..table(destination);
        await insertQuery.insertMany(processedChunk);
      }

      if (chunk.length < chunkSize) break;

      offset += chunkSize;
    }
  }

  @override
  Future<bool> parallelBulkInsert(
    List<Map<String, dynamic>> data, {
    int parallelism = 2,
    int batchSize = 1000,
    ConflictAction conflictAction = ConflictAction.ignore,
    List<String>? conflictColumns,
  }) async {
    if (data.isEmpty) {
      throw InvalidArgumentException(
          'Data cannot be empty for parallel bulk insert operation');
    }

    try {
      final chunkSize = (data.length / parallelism).ceil();
      final futures = <Future<bool>>[];

      for (int i = 0; i < parallelism; i++) {
        final start = i * chunkSize;
        final end = (start + chunkSize).clamp(0, data.length);

        if (start >= data.length) break;

        final chunk = data.sublist(start, end);

        final future = bulkInsert(
          chunk,
          conflictAction: conflictAction,
          conflictColumns: conflictColumns,
          batchSize: batchSize,
        );

        futures.add(future);
      }

      final results = await Future.wait(futures);
      return results.every((result) => result);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> transactionalBulkOperation(
    Future<void> Function() operations,
  ) async {
    try {
      return await transaction(() async {
        await operations();
      });
    } catch (e) {
      rethrow;
    }
  }

  @protected
  void clearBulkOperations() {
    _paramCounter = 0;
  }
}
