import 'package:meta/meta.dart';

import '../../contract/database/query_builder/query_builder.dart'
    show QueryBuilder;
import '../../exception/invalid_argument_exception.dart';

abstract mixin class InsertQueryBuilderImpl implements QueryBuilder {
  @protected
  @override
  final Map<String, dynamic> bindings = {};

  int _paramCounter = 0;

  String _nextParamName() {
    _paramCounter++;
    return 'p$_paramCounter';
  }

  @override
  Future<bool> insert(
    Map<String, dynamic> values,
  ) async {
    try {
      if (values.isEmpty) {
        throw InvalidArgumentException(
          "Values map cannot be empty for insert operation.",
        );
      }

      final conn = getConnection();
      final columns = values.keys.toList();
      final paramBindings = <String, dynamic>{};

      // Create parameter placeholders
      final placeholders = values.keys.map((key) {
        final paramName = _nextParamName();
        paramBindings[paramName] = values[key];
        return ":$paramName";
      }).join(", ");

      final query =
          "INSERT INTO $table (${columns.join(', ')}) VALUES ($placeholders)";
      await conn.insert(query, paramBindings);
      return true;
    } catch (e) {
      throw Exception(e);
    }
  }

  @override
  Future insertGetId(
    Map<String, dynamic> values, [
    String? sequence,
  ]) async {
    var columns = values.keys.toList();
    String cols = columns.join(", ");
    String vals = columns.map((col) => formatValue(values[col])).join(", ");
    String sql = "INSERT INTO $table ($cols) VALUES ($vals)";
    final id = await dbConnection?.insert(sql);
    return id;
  }

  @override
  Future<bool> insertMany(
    List<Map<String, dynamic>> valuesList,
  ) async {
    try {
      if (valuesList.isEmpty) {
        throw InvalidArgumentException(
          "Values list cannot be empty for insertMany operation.",
        );
      }

      // Ensure all maps have the same keys
      final firstItem = valuesList.first;
      final columns = firstItem.keys.toList();

      for (var values in valuesList) {
        if (!_haveSameKeys(values, firstItem)) {
          throw InvalidArgumentException(
            "All items in the values list must have the same structure.",
          );
        }
      }

      final conn = getConnection();
      final paramBindings = <String, dynamic>{};
      final valueGroups = <String>[];

      // Create parameter placeholders for each row
      for (var values in valuesList) {
        final placeholders = columns.map((column) {
          final paramName = _nextParamName();
          paramBindings[paramName] = values[column];
          return ":$paramName";
        }).join(", ");

        valueGroups.add("($placeholders)");
      }

      final query =
          "INSERT INTO $table (${columns.join(', ')}) VALUES ${valueGroups.join(', ')}";

      await conn.execute(query, paramBindings);
      return true;
    } catch (e) {
      throw Exception(e);
    }
  }

  bool _haveSameKeys(Map<String, dynamic> map1, Map<String, dynamic> map2) {
    if (map1.keys.length != map2.keys.length) return false;

    for (var key in map1.keys) {
      if (!map2.containsKey(key)) return false;
    }

    return true;
  }

  @override
  Future<bool> insertOrIgnore(
    Map<String, dynamic> values,
  ) async {
    var columns = values.keys.toList();
    String cols = columns.join(", ");
    String vals = columns.map((col) => formatValue(values[col])).join(", ");
    String sql = "INSERT IGNORE INTO $table ($cols) VALUES ($vals)";
    await dbConnection?.execute(sql);
    return true;
  }

  @override
  Future<bool> insertUsing(
    List<String> columns,
    QueryBuilder subQuery,
  ) async {
    String cols = columns.join(", ");
    String subSql = subQuery.toSql();
    String sql = "INSERT INTO $table ($cols) $subSql";
    await dbConnection?.execute(sql);
    return true;
  }

  @override
  Future<bool> upsert(
    Map<String, dynamic> values,
    List<String> uniqueBy, [
    Map<String, dynamic>? update,
  ]) async {
    var columns = values.keys.toList();
    String cols = columns.join(", ");
    String vals = columns.map((col) => formatValue(values[col])).join(", ");

    String sql = "INSERT INTO $table ($cols) VALUES ($vals)";

    if (update == null) {
      update = Map.from(values);
      for (var col in uniqueBy) {
        update.remove(col);
      }
    }

    if (update.isNotEmpty) {
      String updates = update.entries
          .map((e) => "${e.key} = ${formatValue(e.value)}")
          .join(", ");
      sql += " ON DUPLICATE KEY UPDATE $updates";
    }

    await dbConnection?.execute(sql);
    return true;
  }
}
