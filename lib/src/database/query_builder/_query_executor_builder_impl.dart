import 'dart:math' as math;

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
    var result = await dbConnection?.select(sql);
    return num.tryParse(result?.first.values.first) ?? 0;
  }

  @override
  Future<void> chunk(
    int count,
    void Function(List<Map<String, dynamic>> chunk) callback,
  ) async {
    var results = await get();
    for (int i = 0; i < results.length; i += count) {
      int end = (i + count < results.length) ? i + count : results.length;
      var chunkData = results.sublist(i, end);
      callback(chunkData);
    }
  }

  @override
  Future<void> chunkById(
    int count,
    void Function(List<Map<String, dynamic>> chunk) callback, [
    String? column = 'id',
  ]) async {
    var results = await get();
    results.sort((a, b) {
      var valA = a[column];
      var valB = b[column];
      if (valA is Comparable && valB is Comparable) {
        return valA.compareTo(valB);
      }
      return 0;
    });
    for (int i = 0; i < results.length; i += count) {
      int end = (i + count > results.length) ? results.length : i + count;
      callback(results.sublist(i, end));
    }
  }

  @override
  Future<int> count([String columns = '*']) async {
    String sql = build(aggregateFunction: "COUNT", aggregateColumn: columns);
    var result = await dbConnection?.select(sql);
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
    String sql = whereEqualTo('id', id).limit(1).toSql();
    final result = await dbConnection!.select(sql);
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
    String sql = limit(1).toSql();
    final result = await dbConnection!.select(sql);
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
    String? operator,
    value,
    List<String> columns = const ['*'],
  ]) async {
    operator ??= "=";

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
    return await dbConnection!.select(toSql());
  }

  @override
  Stream<Iterable<Map<String, dynamic>>> lazy([
    int chunk = 1000,
  ]) async* {
    final results = await get();
    for (int i = 0; i < results.length; i += chunk) {
      yield results.sublist(i, math.min(i + chunk, results.length));
    }
  }

  @override
  Future max(String column) async {
    String sql = build(aggregateFunction: "MAX", aggregateColumn: column);
    var result = await dbConnection?.select(sql);
    return result?.first.values.first;
  }

  @override
  Future min(String column) async {
    String sql = build(aggregateFunction: "MIN", aggregateColumn: column);
    var result = await dbConnection?.select(sql);
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
    String sql = take(perPage).skip(offset).toSql();
    final pageData = await dbConnection?.select(sql);

    final isFirst = currentPage == 1;
    final isLast = currentPage == lastPage;
    final hasMore = currentPage < lastPage;

    return PaginatedResult(
            data: pageData ?? [],
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
    String sql = take(perPage).skip(offset).toSql();
    final pageData = await dbConnection?.select(sql);

    return {
      'data': pageData ?? [],
      'current_page': currentPage,
      'per_page': perPage,
      'total': total,
      'last_page': lastPage,
    };
  }

  @override
  Future<num> sum(String column) async {
    String sql = build(aggregateFunction: "SUM", aggregateColumn: column);
    var result = await dbConnection?.select(sql);
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
