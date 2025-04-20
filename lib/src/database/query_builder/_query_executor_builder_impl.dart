import '../../exception/invalid_argument_exception.dart';

import '../../contract/database/query_builder/query_builder.dart'
    show PaginatedResult, QueryBuilder;

abstract mixin class QueryExecutorBuilderImpl implements QueryBuilder {
  @override
  Future<num> avg(
    String column,
  ) async {
    String sql = build(
      aggregateFunction: "AVG",
      aggregateColumn: column,
    );
    final bindings = getBindings();
    var result = await dbConnection?.select(sql, bindings);
    return num.tryParse(result?.first.values.first) ?? 0;
  }

  @override
  Future<void> chunk(
    int chunk,
    void Function(List<Map<String, dynamic>> data) callback,
  ) async {
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
  }

  @override
  Future<void> chunkById(
    int chunk,
    void Function(List<Map<String, dynamic>> data) callback, [
    String column = 'id',
  ]) async {
    int lastId = 0;

    while (true) {
      whereGreaterThan(column, lastId).orderByAsc(column).limit(chunk);
      final result = await get();
      if (result.first[column] == null) {
        throw ();
      }
      if (result.isEmpty) {
        break;
      }

      callback(result);
      lastId += result.last[column] as int;

      if (result.length < chunk) {
        break;
      }
    }
  }

  @override
  Future<int> count([String columns = '*']) async {
    String sql = build(aggregateFunction: "COUNT", aggregateColumn: columns);
    var result = await dbConnection?.select(sql, bindings);
    return int.tryParse(result?.first.values.first) ?? 0;
  }

  @override
  Future<bool> doesntExist() async {
    String sql = "SELECT NOT EXISTS(SELECT 1 $table";
    if (conditions.isNotEmpty) {
      sql += " WHERE ${conditions.join('')}";
    }
    sql += ") as `exists`";
    var result = await dbConnection!.select(sql);
    return (int.tryParse(result.first["exists"]) == 1);
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
    String sql = "SELECT EXISTS(SELECT 1 $table";
    if (conditions.isNotEmpty) {
      sql += " WHERE ${conditions.join('')}";
    }
    sql += ") as `exists`";
    var result = await dbConnection!.select(sql);
    return (int.tryParse(result.first["exists"]) == 1);
  }

  @override
  Future<Map<String, dynamic>?> find(
    dynamic id, [
    List<String> columns = const ['*'],
  ]) async {
    final bindings = getBindings();
    String sql = whereEqualTo('$table.id', id).limit(1).toSql();
    final result = await dbConnection!.select(sql, bindings);
    if (result.isEmpty) {
      return null;
    }
    return result.first;
  }

  @override
  Future<Map<String, dynamic>?> findOrFail(
    id, [
    List<String> columns = const ['*'],
  ]) async {
    var result = await find(id, columns);
    if (result == null) {
      throw InvalidArgumentException("Record with id $id not found.");
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>?> first([
    List<String> columns = const ['*'],
  ]) async {
    final bindings = getBindings();
    String sql = limit(1).toSql();

    final result = await dbConnection!.select(sql, bindings);
    if (result.isEmpty) {
      return null;
    }
    return result.first;
  }

  @override
  Future<Map<String, dynamic>?> firstOrFail([
    List<String> columns = const ['*'],
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
    List<String> columns = const ['*'],
  ]) async {
    if (value == null) {
      throw InvalidArgumentException(
        "Invalid input: Value cannot be null. A valid value must be provided for the firstWhere method.",
      );
    }

    conditions.add("$column $operator ${formatValue(value)}");
    return await first(columns);
  }

  @override
  Future<List<Map<String, dynamic>>> get([
    List<String> columns = const ['*'],
  ]) async {
    try {
      final bindings = getBindings();
      final sql = toSql();
      return await dbConnection!.select(sql, bindings);
    } catch (e) {
      throw Exception(e);
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
  Stream<Map<String, dynamic>> cursor() async* {
    final result = await get();
    for (Map<String, dynamic> row in result) {
      yield row;
    }
  }

  @override
  Future max(String column) async {
    final bindings = getBindings();
    String sql = build(aggregateFunction: "MAX", aggregateColumn: column);
    var result = await dbConnection?.select(sql, bindings);
    return result?.first.values.first;
  }

  @override
  Future min(String column) async {
    final bindings = getBindings();
    String sql = build(aggregateFunction: "MIN", aggregateColumn: column);
    var result = await dbConnection?.select(sql, bindings);
    return result?.first.values.first;
  }

  @override
  Future<Map<String, dynamic>> paginate({
    int perPage = 15,
    List<String> columns = const ['*'],
    String? pageName,
    int? page,
  }) async {
    int currentPage = page ?? 1;
    int total = await count();
    final lastPage = (total / perPage).ceil();
    final offset = (currentPage - 1) * perPage;
    final pageData = await take(perPage).skip(offset).get();
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
    List<String> columns = const ['*'],
    String? pageName,
    int? page,
  ]) async {
    int currentPage = page ?? 1;
    int total = await count();
    final lastPage = (total / perPage).ceil();
    final offset = (currentPage - 1) * perPage;
    final pageData = await take(perPage).skip(offset).get();

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
    final bindings = getBindings();
    String sql = build(aggregateFunction: "SUM", aggregateColumn: column);

    var result = await dbConnection?.select(sql, bindings);
    return num.tryParse(result?.first.values.first) ?? 0;
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
