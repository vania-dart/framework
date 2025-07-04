import '../../contract/database/_connectors/_database_connection.dart';
import '../../contract/database/query_builder/query_builder.dart'
    show QueryBuilder;
import '../../exception/invalid_argument_exception.dart';

abstract mixin class UpdateQueryBuilderImpl implements QueryBuilder {
  late DatabaseConnection conn;
  @override
  Future<bool> update(Map<String, dynamic> values) async {
    try {
      if (values.isEmpty) {
        throw InvalidArgumentException('Update values cannot be empty');
      }

      List<String> setStatements = [];
      for (var entry in values.entries) {
        final paramName = 'update_${entry.key}';
        bindings[paramName] = entry.value;
        setStatements.add("${entry.key} = :$paramName");
      }

      String sql =
          "UPDATE $getTable${buildJoins()} SET ${setStatements.join(", ")}${buildWhereClause()}";
      conn = await getConnection();
      return await conn.execute(sql, bindings);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> updateMany(
    List<Map<String, dynamic>> updates,
    String column,
  ) async {
    try {
      if (updates.isEmpty) return false;

      Set<String> columns = {};
      for (var row in updates) {
        columns.addAll(row.keys.where((key) => key != column));
      }
      List<String> setClauses = [];
      var caseCounter = 0;

      for (var col in columns) {
        List<String> cases = [];
        for (var row in updates) {
          if (row.containsKey(col)) {
            final keyParamName = 'key_$caseCounter';
            final valueParamName = 'value_$caseCounter';
            bindings[keyParamName] = row[column];
            bindings[valueParamName] = row[col];
            cases.add("WHEN $column = :$keyParamName THEN :$valueParamName");
            caseCounter++;
          }
        }
        setClauses.add("$col = CASE ${cases.join(" ")} ELSE $col END");
      }

      List<String> whereValues = [];
      for (var i = 0; i < updates.length; i++) {
        final paramName = 'where_$i';
        bindings[paramName] = updates[i][column];
        whereValues.add(":$paramName");
      }

      String sql =
          "UPDATE $getTable${buildJoins()} SET ${setClauses.join(", ")} WHERE $column IN (${whereValues.join(", ")})";
      conn = await getConnection();
      return await conn.execute(sql, bindings);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> updateOrInsert(
    Map<String, dynamic> search,
    Map<String, dynamic> update,
  ) async {
    Map<String, dynamic> data = {}
      ..addAll(search)
      ..addAll(update);

    return upsert(data, search.keys.toList(), update);
  }

  @override
  Future<bool> increment(
    String column, [
    int amount = 1,
    Map<String, dynamic> extra = const {},
  ]) async {
    try {
      final paramName = 'inc_amount';
      bindings[paramName] = amount;

      String setClause = "$column = $column + :$paramName";
      if (extra.isNotEmpty) {
        var extraCounter = 0;
        List<String> extraClauses = [];

        for (var entry in extra.entries) {
          final extraParamName = 'extra_${extraCounter++}';
          bindings[extraParamName] = entry.value;
          extraClauses.add("${entry.key} = :$extraParamName");
        }
        setClause += ", ${extraClauses.join(", ")}";
      }

      String sql =
          "UPDATE $getTable${buildJoins()} SET $setClause${buildWhereClause()}";
      conn = await getConnection();
      return await conn.execute(sql, bindings);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> decrement(
    String column, [
    int amount = 1,
    Map<String, dynamic> extra = const {},
  ]) async {
    try {
      final paramName = 'dec_amount';
      bindings[paramName] = amount;

      String setClause = "$column = $column - :$paramName";
      if (extra.isNotEmpty) {
        var extraCounter = 0;
        List<String> extraClauses = [];

        for (var entry in extra.entries) {
          final extraParamName = 'extra_${extraCounter++}';
          bindings[extraParamName] = entry.value;
          extraClauses.add("${entry.key} = :$extraParamName");
        }
        setClause += ", ${extraClauses.join(", ")}";
      }

      String sql =
          "UPDATE $getTable${buildJoins()} SET $setClause${buildWhereClause()}";
      conn = await getConnection();
      return await conn.execute(sql, bindings);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> incrementEach(
    Map<String, int> increments, [
    Map<String, dynamic> extra = const {},
  ]) async {
    try {
      List<String> setClauses = [];
      var counter = 0;

      for (var entry in increments.entries) {
        final paramName = 'inc_${counter++}';
        bindings[paramName] = entry.value;
        setClauses.add("${entry.key} = ${entry.key} + :$paramName");
      }

      if (extra.isNotEmpty) {
        for (var entry in extra.entries) {
          final paramName = 'extra_${counter++}';
          bindings[paramName] = entry.value;
          setClauses.add("${entry.key} = :$paramName");
        }
      }

      String sql =
          "UPDATE $getTable${buildJoins()} SET ${setClauses.join(", ")}${buildWhereClause()}";
      conn = await getConnection();
      return await conn.execute(sql, bindings);
    } catch (e) {
      rethrow;
    }
  }
}
