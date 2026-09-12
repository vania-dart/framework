import 'package:mongo_dart/mongo_dart.dart';

typedef QueryCallback = QueryBuilder Function(QueryBuilder qb);

enum ConflictAction { ignore, update, replace, delete }

abstract class QueryBuilder {
  String? get connectionName;
  String get getTable;

  QueryBuilder connection([String? connection]);
  QueryBuilder table(String table, [String? as]);
  QueryBuilder collection(String collection);

  /// Drops every filter accumulated so far, keeping the collection and
  /// connection. Mirrors `QueryBuilder.resetQuery` in core.
  void resetQuery();

  QueryBuilder select([List<String> columns = const ['*']]);
  QueryBuilder addSelect(List<String> columns);
  QueryBuilder selectRaw(String query, [List bindings = const []]);
  QueryBuilder selectSub(QueryBuilder subQuery, String as);

  QueryBuilder where(
    dynamic condition, [
    String operator = '=',
    dynamic value,
    String boolean = 'and',
  ]);
  QueryBuilder orWhere(
    dynamic condition, [
    String operator = '=',
    dynamic value,
  ]);
  QueryBuilder whereEqualTo(
    dynamic condition, [
    dynamic value,
    String boolean = 'and',
  ]);
  QueryBuilder whereNotEqualTo(
    dynamic condition, [
    dynamic value,
    String boolean = 'and',
  ]);
  QueryBuilder whereGreaterThan(
    dynamic condition, [
    dynamic value,
    String boolean = 'and',
  ]);
  QueryBuilder whereGreaterThanOrEqualTo(
    dynamic condition, [
    dynamic value,
    String boolean = 'and',
  ]);
  QueryBuilder whereLessThan(
    dynamic condition, [
    dynamic value,
    String boolean = 'and',
  ]);
  QueryBuilder whereLessThanOrEqualTo(
    dynamic condition, [
    dynamic value,
    String boolean = 'and',
  ]);
  QueryBuilder whereIn(
    String column,
    List values, {
    String boolean = 'and',
    bool not = false,
  });
  QueryBuilder orWhereIn(String column, List values, {bool not = false});
  QueryBuilder whereNotIn(
    String column,
    dynamic values, {
    String boolean = 'and',
  });
  QueryBuilder orWhereNotIn(String column, dynamic values);
  QueryBuilder whereBetween(
    String column,
    List values, {
    String boolean = 'and',
    bool not = false,
  });
  QueryBuilder whereBetweenColumns(
    String column,
    List<String> columns, {
    String boolean = 'and',
  });
  QueryBuilder orWhereBetween(String column, List values, {bool not = false});
  QueryBuilder whereNotBetween(
    String column,
    List values, {
    String boolean = 'and',
  });
  QueryBuilder whereNotBetweenColumns(
    String column,
    List<String> columns, {
    String boolean = 'and',
  });
  QueryBuilder orWhereNotBetween(String column, List values);
  QueryBuilder whereNull(
    String column, {
    String boolean = 'and',
    bool not = false,
  });
  QueryBuilder orWhereNull(String column);
  QueryBuilder whereNotNull(String column, {String boolean = 'and'});
  QueryBuilder orWhereNotNull(String column);
  QueryBuilder whereLike(
    String column,
    dynamic value, {
    bool caseSensitive = false,
    String boolean = 'and',
  });
  QueryBuilder orWhereLike(
    String column,
    dynamic value, {
    bool caseSensitive = false,
  });
  QueryBuilder whereNotLike(
    String column,
    dynamic value, {
    bool caseSensitive = false,
    String boolean = 'and',
  });
  QueryBuilder orWhereNotLike(
    String column,
    dynamic value, {
    bool caseSensitive = false,
    String boolean = 'and',
  });
  QueryBuilder whereRaw(
    String sql, [
    List<dynamic> rawBindings = const [],
    String boolean = 'and',
  ]);
  QueryBuilder whereRowValues(
    List<String> columns,
    String operator,
    List<dynamic> values, {
    String boolean = 'and',
  });
  QueryBuilder orWhereRaw(String sql, [List<dynamic> rawBindings = const []]);
  QueryBuilder orWhereRowValues(
    List<String> columns,
    String operator,
    List<dynamic> values,
  );
  QueryBuilder rawWhere(Map<String, dynamic> selector);
  QueryBuilder whereColumn(
    String firstColumn,
    String operator,
    String secondColumn, [
    String boolean = 'and',
  ]);
  QueryBuilder orWhereColumn(
    String first,
    String operator,
    String secondColumn,
  );
  QueryBuilder whereJsonContains(
    String column,
    dynamic value, {
    String boolean = 'and',
    bool not = false,
  });
  QueryBuilder orWhereJsonContains(
    String column,
    dynamic value, {
    bool not = false,
  });
  QueryBuilder whereJsonDoesntContain(
    String column,
    dynamic value, {
    String boolean = 'and',
  });
  QueryBuilder orWhereJsonDoesntContain(String column, dynamic value);
  QueryBuilder whereJsonLength(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  });
  QueryBuilder orWhereJsonLength(String column, String operator, dynamic value);
  QueryBuilder whereAll(
    String column,
    List<dynamic> values, {
    String boolean = 'and',
  });
  QueryBuilder whereAny(
    String column,
    List<dynamic> values, {
    String boolean = 'and',
  });
  QueryBuilder whereNone(
    String column,
    List<dynamic> values, {
    String boolean = 'and',
  });
  QueryBuilder whereDate(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  });
  QueryBuilder orWhereDate(String column, String operator, dynamic value);
  QueryBuilder whereDay(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  });
  QueryBuilder orWhereDay(String column, String operator, dynamic value);
  QueryBuilder whereMonth(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  });
  QueryBuilder orWhereMonth(String column, String operator, dynamic value);
  QueryBuilder whereYear(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  });
  QueryBuilder orWhereYear(String column, String operator, dynamic value);
  QueryBuilder whereTime(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  });
  QueryBuilder orWhereTime(String column, String operator, dynamic value);
  QueryBuilder whereHour(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  });
  QueryBuilder orWhereHour(String column, String operator, dynamic value);
  QueryBuilder whereToday(String column, {String boolean = 'and'});
  QueryBuilder whereBeforeToday(String column, {String boolean = 'and'});
  QueryBuilder whereAfterToday(String column, {String boolean = 'and'});
  QueryBuilder whereTodayOrBefore(String column, {String boolean = 'and'});
  QueryBuilder whereTodayOrAfter(String column, {String boolean = 'and'});
  QueryBuilder wherePast(String column, {String boolean = 'and'});
  QueryBuilder whereFuture(String column, {String boolean = 'and'});
  QueryBuilder whereNowOrPast(String column, {String boolean = 'and'});
  QueryBuilder whereNowOrFuture(String column, {String boolean = 'and'});
  QueryBuilder whereFullText(
    dynamic columns,
    dynamic query, [
    Map<String, dynamic> options = const {},
  ]);
  QueryBuilder orWhereFullText(
    dynamic columns,
    dynamic query, [
    Map<String, dynamic> options = const {},
  ]);
  QueryBuilder whereExists(
    QueryCallback callback, {
    String boolean = 'and',
    bool not = false,
  });
  QueryBuilder orWhereExists(QueryCallback callback, {bool not = false});
  QueryBuilder whereNotExists(QueryCallback callback, {String boolean = 'and'});
  QueryBuilder orWhereNotExists(QueryCallback callback);
  QueryBuilder whereHas(
    String relation,
    QueryCallback callback, {
    String boolean = 'and',
  });
  QueryBuilder orWhereHas(String relation, QueryCallback callback);
  QueryBuilder whereDoesntHave(
    String relation,
    QueryCallback callback, {
    String boolean = 'and',
  });
  QueryBuilder orWhereDoesntHave(String relation, QueryCallback callback);
  QueryBuilder withSoftDeletes([String column = 'deleted_at']);

  QueryBuilder groupBy(List<String> groups);

  /// Not supported by the MongoDB driver: there is no raw SQL fragment to
  /// emit. Use an aggregation pipeline instead.
  QueryBuilder groupByRaw(String expression);
  QueryBuilder having(
    String column, [
    String? operator,
    dynamic value,
    String boolean = 'and',
  ]);
  QueryBuilder havingBetween(
    String column,
    List<dynamic> values, {
    String boolean = 'and',
    bool not = false,
  });
  QueryBuilder inRandomOrder([dynamic seed]);
  QueryBuilder latest([String column = 'created_at']);
  QueryBuilder limit(int value);
  QueryBuilder offset(int value);
  QueryBuilder skip(int value);
  QueryBuilder take(int value);
  QueryBuilder orderBy(String column, [String direction = 'ASC']);

  /// Not supported by the MongoDB driver: there is no raw SQL fragment to
  /// emit. Use [orderBy], or an aggregation pipeline for anything more
  /// involved.
  QueryBuilder orderByRaw(String expression);
  QueryBuilder orderByAsc(String column);
  QueryBuilder orderByDesc(String column);
  QueryBuilder reorder([String? column, String? direction]);

  QueryBuilder join(
    String table,
    String first, [
    String? operator,
    String? second,
    String type = 'INNER',
  ]);
  QueryBuilder crossJoin(String table, [List<dynamic> bindings = const []]);
  QueryBuilder joinSub(
    QueryBuilder query,
    String as,
    String first, [
    String? operator,
    String? second,
    String type = 'INNER',
  ]);
  QueryBuilder leftJoin(
    String table,
    String first, [
    String? operator,
    String? second,
  ]);
  QueryBuilder leftJoinSub(
    QueryBuilder query,
    String as,
    String first, [
    String? operator,
    String? second,
  ]);
  QueryBuilder rightJoin(
    String table,
    String first, [
    String? operator,
    String? second,
  ]);
  QueryBuilder union(QueryBuilder query);
  QueryBuilder unionAll(QueryBuilder query);
  QueryBuilder withCte(
    String name,
    QueryBuilder query, {
    List<String>? columns,
  });
  QueryBuilder withMultiple(Map<String, QueryBuilder> queries);
  QueryBuilder withRecursive(
    String name,
    QueryBuilder query, {
    List<String>? columns,
  });
  QueryBuilder withMaterialized(
    String name,
    QueryBuilder query, {
    List<String>? columns,
  });
  QueryBuilder withNotMaterialized(
    String name,
    QueryBuilder query, {
    List<String>? columns,
  });
  QueryBuilder rowNumber({String? partitionBy, String? orderBy, String? as});
  QueryBuilder rank({String? partitionBy, String? orderBy, String? as});
  QueryBuilder denseRank({String? partitionBy, String? orderBy, String? as});
  QueryBuilder lag(
    String column, {
    int offset = 1,
    dynamic defaultValue,
    String? partitionBy,
    String? orderBy,
    String? as,
  });
  QueryBuilder lead(
    String column, {
    int offset = 1,
    dynamic defaultValue,
    String? partitionBy,
    String? orderBy,
    String? as,
  });
  QueryBuilder firstValue(
    String column, {
    String? partitionBy,
    String? orderBy,
    String? as,
  });
  QueryBuilder lastValue(
    String column, {
    String? partitionBy,
    String? orderBy,
    String? as,
  });
  QueryBuilder ntile(
    int buckets, {
    String? partitionBy,
    String? orderBy,
    String? as,
  });
  QueryBuilder percentRank({String? partitionBy, String? orderBy, String? as});
  QueryBuilder cumeDist({String? partitionBy, String? orderBy, String? as});
  QueryBuilder windowSum(
    String column, {
    String? partitionBy,
    String? orderBy,
    String? as,
  });
  QueryBuilder windowAvg(
    String column, {
    String? partitionBy,
    String? orderBy,
    String? as,
  });
  QueryBuilder windowCount(
    String column, {
    String? partitionBy,
    String? orderBy,
    String? as,
  });
  QueryBuilder windowMax(
    String column, {
    String? partitionBy,
    String? orderBy,
    String? as,
  });
  QueryBuilder windowMin(
    String column, {
    String? partitionBy,
    String? orderBy,
    String? as,
  });

  Future<bool> insert(Map<String, dynamic> values);
  Future insertGetId(Map<String, dynamic> values, [String? sequence]);
  Future<bool> insertMany(List<Map<String, dynamic>> valuesList);
  Future<bool> insertOrIgnore(Map<String, dynamic> values);
  Future<bool> insertUsing(List<String> columns, QueryBuilder subQuery);
  Future<bool> upsert(
    Map<String, dynamic> values,
    List<String> uniqueBy, [
    Map<String, dynamic>? update,
  ]);
  Future<bool> update(Map<String, dynamic> values);
  Future<bool> updateMany(List<Map<String, dynamic>> updates, String column);
  Future<bool> updateOrInsert(
    Map<String, dynamic> search,
    Map<String, dynamic> update,
  );
  Future<bool> increment(
    String column, [
    int amount = 1,
    Map<String, dynamic> extra = const {},
  ]);
  Future<bool> decrement(
    String column, [
    int amount = 1,
    Map<String, dynamic> extra = const {},
  ]);
  Future<bool> incrementEach(
    Map<String, int> increments, [
    Map<String, dynamic> extra = const {},
  ]);
  Future<bool> delete();
  Future<bool> truncate({bool force = false});

  Future<List<Map<String, dynamic>>> get([List<String> columns = const ['*']]);
  Future<Map<String, dynamic>?> first([List<String> columns = const ['*']]);
  Future<Map<String, dynamic>?> firstOrFail([
    List<String> columns = const ['*'],
  ]);
  Future<Map<String, dynamic>?> find(
    dynamic id, {
    String byColumnName = '_id',
    List<String> columns = const ['*'],
  });
  Future<Map<String, dynamic>?> findOrFail(
    dynamic id, {
    String byColumnName = '_id',
    List<String> columns = const ['*'],
  });
  Future<Map<String, dynamic>?> firstWhere(
    String column, [
    String? operator = '=',
    dynamic value,
    List<String> columns = const ['*'],
  ]);
  Future<int> count([String columns = '*']);
  Future<bool> exists();
  Future<bool> doesntExist();
  Future<num> avg(String column);
  Future<num> sum(String column);
  Future min(String column);
  Future max(String column);
  Future value(String column);
  Future pluck(String column, [String? key]);
  Future<Map<String, dynamic>> paginate({
    int perPage = 15,
    List<String> columns = const ['*'],
    String? pageName,
    int? page,
  });
  Future<Map<String, dynamic>> simplePaginate([
    int perPage = 15,
    List<String> columns = const ['*'],
    String? pageName,
    int? page,
  ]);
  Future<void> chunk(
    int chunk,
    void Function(List<Map<String, dynamic>> data) callback,
  );
  Future<void> chunkById(
    int chunk,
    void Function(List<Map<String, dynamic>> data) callback, [
    String column = '_id',
  ]);
  Future<void> each(void Function(Map<String, dynamic> q) callback);
  Stream<Iterable<Map<String, dynamic>>> lazy([
    int chunk = 100,
    String column = '_id',
  ]);
  Stream<Map<String, dynamic>> cursor([int chunk = 1000]);

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
  Future<bool> transactionalBulkOperation(Future<bool> Function() action);
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

  Map<String, dynamic> getBindings();
  Map<String, dynamic> toSelector();
  String toSql();
  String toRawSql();
  DbCollection get mongoCollection;
}
