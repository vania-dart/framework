import 'package:meta/meta.dart';

import '../../contract/database/_connectors/_database_connection.dart';
import '../../contract/database/query_builder/query_builder.dart'
    show QueryBuilder;
import '../../exception/invalid_argument_exception.dart';

abstract mixin class InsertQueryBuilderImpl implements QueryBuilder {
  late DatabaseConnection conn;

  @protected
  @override
  final Map<String, dynamic> bindings = {};

  int _paramCounter = 0;

  String _nextParamName() {
    _paramCounter++;
    return 'p$_paramCounter';
  }

  @override
  Future<bool> insert(Map<String, dynamic> values) async {
    try {
      if (values.isEmpty) {
        throw InvalidArgumentException(
          "Values map cannot be empty for insert operation.",
        );
      }

      conn = await getConnection();
      final columns = values.keys.toList();
      final paramBindings = <String, dynamic>{};

      // Create parameter placeholders
      final placeholders = values.keys
          .map((key) {
            final paramName = _nextParamName();
            paramBindings[paramName] = values[key];
            return ":$paramName";
          })
          .join(", ");

      final query =
          "INSERT INTO $getTable (${columns.join(', ')}) VALUES ($placeholders)";
      await conn.insert(query, paramBindings);
      return true;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future insertGetId(Map<String, dynamic> values, [String? sequence]) async {
    try {
      if (values.isEmpty) {
        throw InvalidArgumentException(
          "Values map cannot be empty for insertGetId operation.",
        );
      }

      conn = await getConnection();
      final columns = values.keys.toList();
      final paramBindings = <String, dynamic>{};

      final placeholders = values.keys
          .map((key) {
            final paramName = _nextParamName();
            paramBindings[paramName] = values[key];
            return ":$paramName";
          })
          .join(", ");

      final query =
          "INSERT INTO $getTable (${columns.join(', ')}) VALUES ($placeholders)";
      final id = await conn.insert(query, paramBindings);
      return id;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> insertMany(List<Map<String, dynamic>> valuesList) async {
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

      conn = await getConnection();
      final paramBindings = <String, dynamic>{};
      final valueGroups = <String>[];

      // Create parameter placeholders for each row
      for (var values in valuesList) {
        final placeholders = columns
            .map((column) {
              final paramName = _nextParamName();
              paramBindings[paramName] = values[column];
              return ":$paramName";
            })
            .join(", ");

        valueGroups.add("($placeholders)");
      }

      final query =
          "INSERT INTO $getTable (${columns.join(', ')}) VALUES ${valueGroups.join(', ')}";

      await conn.execute(query, paramBindings);
      return true;
    } catch (e) {
      rethrow;
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
  Future<bool> insertOrIgnore(Map<String, dynamic> values) async {
    try {
      if (values.isEmpty) {
        throw InvalidArgumentException(
          "Values map cannot be empty for insertOrIgnore operation.",
        );
      }
      conn = await getConnection();
      final columns = values.keys.toList();
      final paramBindings = <String, dynamic>{};
      final placeholders = values.keys
          .map((key) {
            final paramName = _nextParamName();
            paramBindings[paramName] = values[key];
            return ":$paramName";
          })
          .join(", ");

      final query =
          "INSERT IGNORE INTO $getTable (${columns.join(', ')}) VALUES ($placeholders)";
      await conn.execute(query, paramBindings);
      return true;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> insertUsing(List<String> columns, QueryBuilder subQuery) async {
    try {
      String cols = columns.join(", ");
      String subSql = subQuery.toRawSql();
      String sql = "INSERT INTO $getTable ($cols) $subSql";
      conn = await getConnection();
      await conn.execute(sql);
      return true;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> upsert(
    Map<String, dynamic> values,
    List<String> uniqueBy, [
    Map<String, dynamic>? update,
  ]) async {
    try {
      if (values.isEmpty) {
        throw InvalidArgumentException(
          "Values map cannot be empty for upsert operation.",
        );
      }

      conn = await getConnection();
      final columns = values.keys.toList();
      final paramBindings = <String, dynamic>{};

      final placeholders = values.keys
          .map((key) {
            final paramName = _nextParamName();
            paramBindings[paramName] = values[key];
            return ":$paramName";
          })
          .join(", ");

      String sql =
          "INSERT INTO $getTable (${columns.join(', ')}) VALUES ($placeholders)";

      if (update == null) {
        update = Map.from(values);
        for (var col in uniqueBy) {
          update.remove(col);
        }
      }

      if (update.isNotEmpty) {
        final updateClauses = update.entries
            .map((entry) {
              final paramName = _nextParamName();
              paramBindings[paramName] = entry.value;
              return "${entry.key} = :$paramName";
            })
            .join(", ");

        sql += " ON DUPLICATE KEY UPDATE $updateClauses";
      }

      await conn.execute(sql, paramBindings);
      return true;
    } catch (e) {
      rethrow;
    }
  }
}
