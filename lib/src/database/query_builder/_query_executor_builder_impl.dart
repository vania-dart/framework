import '../../contract/database/_connectors/_database_connection.dart';
import '../../exception/invalid_argument_exception.dart';

import '../../contract/database/query_builder/query_builder.dart'
    show PaginatedResult, QueryBuilder;

abstract mixin class QueryExecutorBuilderImpl implements QueryBuilder {
  late DatabaseConnection conn;
  @override
  Future<num> avg(
    String column,
  ) async {
    try {
      String sql = build(
        aggregateFunction: "AVG",
        aggregateColumn: column,
      );
      final bindings = getBindings();
      conn = await getConnection();
      var result = await conn.select(sql, bindings);
      return num.tryParse(result.first.values.first.toString()) ?? 0;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> chunk(
    int chunk,
    void Function(List<Map<String, dynamic>> data) callback,
  ) async {
    try {
      int offset = 0;
      while (true) {
        limit(chunk).offset(offset);
        final result = await get();
        if (result.isEmpty) {
          break;
        }
        callback(result);
        offset += chunk;
        if (result.length < chunk) {
          break;
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> chunkById(
    int chunk,
    void Function(List<Map<String, dynamic>> data) callback, [
    String column = 'id',
  ]) async {
    try {
      int lastId = 0;

      while (true) {
        whereGreaterThan(column, lastId).orderByAsc(column).limit(chunk);
        final result = await get();
        if (result.isEmpty) {
          break;
        }
        callback(result);
        lastId = int.parse(result.last[column].toString());

        if (result.length < chunk) {
          break;
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<int> count([String columns = '*']) async {
    try {
      final bindings = getBindings();
      String sql = build(aggregateFunction: "COUNT", aggregateColumn: columns);
      conn = await getConnection();
      var result = await conn.select(sql, bindings);
      return int.tryParse(result.first.values.first.toString()) ?? 0;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> doesntExist() async {
    try {
      String sql = "SELECT NOT EXISTS(SELECT 1 FROM $getTable";
      if (conditions.isNotEmpty) {
        sql += " WHERE ${conditions.join('')}";
      }
      sql += ") as `exists`";
      final bindings = getBindings();
      var result = await dbConnection!.select(sql, bindings);

      return (int.tryParse(result.first["exists"].toString()) == 1);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> each(
    void Function(Map<String, dynamic> q) callback,
  ) async {
    var results = await get();
    for (var row in results) {
      callback(row);
    }
  }

  @override
  Future<bool> exists() async {
    try {
      String sql = "SELECT EXISTS(SELECT 1 FROM $getTable";
      if (conditions.isNotEmpty) {
        sql += " WHERE ${conditions.join('')}";
      }
      sql += ") as `exists`";
      final bindings = getBindings();
      var result = await dbConnection!.select(sql, bindings);
      return (int.tryParse(result.first["exists"].toString()) == 1);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> find(
    dynamic id, {
    String byColumnName = 'id',
    List<String> columns = const [],
  }) async {
    try {
      String sql = whereEqualTo('$getTable.$byColumnName', id).limit(1).toSql();
      if (columns.isNotEmpty) {
        for (String column in columns) {
          selectColumns.remove(column);
        }
        selectColumns.addAll(columns);
      }
      final bindings = getBindings();
      final result = await dbConnection!.select(sql, bindings);
      if (result.isEmpty) {
        return null;
      }
      return result.first;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> findOrFail(
    id, {
    String byColumnName = 'id',
    List<String> columns = const [],
  }) async {
    var result = await find(
      id,
      byColumnName: byColumnName,
      columns: columns,
    );
    if (result == null) {
      throw InvalidArgumentException("Record with id $id not found.");
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>?> first([
    List<String> columns = const [],
  ]) async {
    try {
      if (columns.isNotEmpty) {
        for (String column in columns) {
          selectColumns.remove(column);
        }
        selectColumns.addAll(columns);
      }
      final bindings = getBindings();
      String sql = limit(1).toSql();
      conn = await getConnection();
      final result = await conn.select(sql, bindings);
      if (result.isEmpty) {
        return null;
      }
      return result.first;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> firstOrFail([
    List<String> columns = const [],
  ]) async {
    var result = await first(columns);
    if (result == null) {
      throw InvalidArgumentException("No records found.");
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>?> firstWhere(
    String column, [
    String? operator = '=',
    value,
    List<String> columns = const [],
  ]) async {
    if (value == null) {
      throw InvalidArgumentException(
        "Invalid input: Value cannot be null. A valid value must be provided for the firstWhere method.",
      );
    }
    where(column, operator ?? '=', value);
    return await first(columns);
  }

  @override
  Future<List<Map<String, dynamic>>> get([
    List<String> columns = const [],
  ]) async {
    try {
      final bindings = getBindings();
      if (columns.isNotEmpty) {
        for (String column in columns) {
          selectColumns.remove(column);
        }
        selectColumns.addAll(columns);
      }
      final sql = toSql();
      conn = await getConnection();
      return await conn.select(sql, bindings);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Stream<Iterable<Map<String, dynamic>>> lazy([
    int chunk = 100,
    String column = 'id',
  ]) async* {
    int offset = 0;
    while (true) {
      orderByAsc(column).limit(chunk).offset(offset);
      final result = await get();
      if (result.isEmpty) {
        break;
      }
      yield result;
      offset += chunk;
      if (result.length < chunk) {
        break;
      }
    }
  }

  @override
  Stream<Map<String, dynamic>> cursor([
    int chunk = 1000,
  ]) async* {
    try {
      int offset = 0;

      while (true) {
        limit(chunk).offset(offset);

        final result = await get();
        if (result.isEmpty) {
          break;
        }

        for (final row in result) {
          yield row;
        }

        offset += chunk;

        if (result.length < chunk) {
          break;
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future max(String column) async {
    try {
      final bindings = getBindings();
      String sql = build(aggregateFunction: "MAX", aggregateColumn: column);
      conn = await getConnection();
      var result = await conn.select(sql, bindings);
      return result.first.values.first;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future min(String column) async {
    try {
      final bindings = getBindings();
      String sql = build(aggregateFunction: "MIN", aggregateColumn: column);
      conn = await getConnection();
      var result = await conn.select(sql, bindings);
      return result.first.values.first;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> paginate({
    int perPage = 15,
    List<String> columns = const [],
    String? pageName,
    int? page,
  }) async {
    int currentPage = page ?? 1;
    int total = await count();
    final lastPage = (total / perPage).ceil();
    final offset = (currentPage - 1) * perPage;
    final pageData = await take(perPage).skip(offset).get(columns);
    final isFirst = currentPage == 1;
    final isLast = currentPage == lastPage;
    final hasMore = currentPage < lastPage;

    return PaginatedResult(
            data: pageData,
            currentPage: currentPage,
            perPage: perPage,
            total: total,
            lastPage: lastPage,
            isFirst: isFirst,
            isLast: isLast,
            hasMore: hasMore)
        .toMap();
  }

  @override
  Future pluck(String column, [String? key]) async {
    var results = await get();
    if (key == null) {
      return results.map((row) => row[column]).toList();
    } else {
      Map<dynamic, dynamic> resultMap = {};
      for (var row in results) {
        resultMap[row[key]] = row[column];
      }
      return resultMap;
    }
  }

  @override
  Future<Map<String, dynamic>> simplePaginate([
    int perPage = 15,
    List<String> columns = const [],
    String? pageName,
    int? page,
  ]) async {
    int currentPage = page ?? 1;
    int total = await count();
    final lastPage = (total / perPage).ceil();
    final offset = (currentPage - 1) * perPage;
    final pageData = await take(perPage).skip(offset).get(columns);

    return {
      'data': pageData,
      'current_page': currentPage,
      'per_page': perPage,
      'total': total,
      'last_page': lastPage,
    };
  }

  @override
  Future<num> sum(String column) async {
    try {
      final bindings = getBindings();
      String sql = build(aggregateFunction: "SUM", aggregateColumn: column);
      conn = await getConnection();
      var result = await conn.select(sql, bindings);
      return num.tryParse(result.first.values.first.toString()) ?? 0;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future value(String column) async {
    final response = await first();
    if (response != null && response.containsKey(column)) {
      return response[column];
    }

    return null;
  }
}
