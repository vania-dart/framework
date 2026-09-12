import 'package:mongo_dart/mongo_dart.dart';
import 'package:vania/database.dart' show PaginatedResult;
import 'package:vania/foundation.dart' show InvalidArgumentException, getParam;

import '../db.dart';
import '../../contract/database/query_builder/query_builder.dart';

class MongoQueryBuilderImpl implements QueryBuilder {
  MongoQueryBuilderImpl([DbCollection? collection]) : _collection = collection;

  DbCollection? _collection;
  String? _collectionName;
  String _connectionName = 'mongodb';
  List<String> _columns = const ['*'];
  int? _limit;
  int? _skip;
  final Map<String, int> _sort = {};
  final List<Map<String, dynamic>> _andFilters = [];
  final List<Map<String, dynamic>> _orFilters = [];
  final Map<String, dynamic> _bindings = {};

  @override
  String? get connectionName => _connectionName;

  @override
  void resetQuery() {
    _columns = const ['*'];
    _limit = null;
    _skip = null;
    _sort.clear();
    _andFilters.clear();
    _orFilters.clear();
    _bindings.clear();
  }

  @override
  String get getTable => _collectionName ?? _collection?.collectionName ?? '';

  @override
  DbCollection get mongoCollection {
    final collection = _collection;
    if (collection == null) {
      throw InvalidArgumentException(
        'MongoDB collection has not been selected.',
      );
    }
    return collection;
  }

  @override
  QueryBuilder addSelect(List<String> columns) {
    if (_columns.length == 1 && _columns.first == '*') {
      _columns = [];
    }
    _columns = [..._columns, ...columns];
    return this;
  }

  @override
  Future<num> avg(String column) async {
    final values = await _numericValues(column);
    if (values.isEmpty) return 0;
    return values.reduce((left, right) => left + right) / values.length;
  }

  @override
  Future<void> batchProcess({
    required int batchSize,
    required Future<void> Function(
      List<Map<String, dynamic>> batch,
      int batchNumber,
    )
    processor,
    List<String> columns = const ['*'],
  }) async {
    var batchNumber = 1;
    var offset = 0;
    while (true) {
      final batch = await _fresh().take(batchSize).skip(offset).get(columns);
      if (batch.isEmpty) return;
      await processor(batch, batchNumber);
      if (batch.length < batchSize) return;
      offset += batchSize;
      batchNumber++;
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
        'Column and values must be provided for bulk delete operation',
      );
    }
    for (var i = 0; i < values.length; i += batchSize) {
      final batch = values.skip(i).take(batchSize).toList();
      await _fresh().whereIn(column, batch).delete();
    }
    return true;
  }

  @override
  Future<bool> bulkDeleteWhere(
    List<Map<String, dynamic>> conditions, {
    int batchSize = 500,
  }) async {
    if (conditions.isEmpty) {
      throw InvalidArgumentException(
        'Conditions cannot be empty for bulk delete operation',
      );
    }
    for (var i = 0; i < conditions.length; i += batchSize) {
      final batch = conditions.skip(i).take(batchSize).toList();
      await mongoCollection.deleteMany({'\$or': batch});
    }
    return true;
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
        'Data cannot be empty for bulk insert operation',
      );
    }
    for (var i = 0; i < data.length; i += batchSize) {
      final batch = data.skip(i).take(batchSize).toList();
      if (conflictAction == ConflictAction.update && conflictColumns != null) {
        for (final row in batch) {
          final search = {for (final key in conflictColumns) key: row[key]};
          final update = {
            for (final entry in row.entries)
              if (!conflictColumns.contains(entry.key) &&
                  (updateColumns == null || updateColumns.contains(entry.key)))
                entry.key: entry.value,
          };
          await updateOrInsert(search, update);
        }
      } else {
        await insertMany(batch);
      }
    }
    return true;
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
        'Updates cannot be empty for bulk update operation',
      );
    }
    for (var i = 0; i < updates.length; i += batchSize) {
      final batch = updates.skip(i).take(batchSize).toList();
      for (final row in batch) {
        final values = <String, dynamic>{};
        final columns =
            updateColumns ?? row.keys.where((key) => key != matchColumn);
        for (final column in columns) {
          if (row.containsKey(column)) values[column] = row[column];
        }
        if (additionalValues != null) values.addAll(additionalValues);
        await _fresh()
            .whereEqualTo(matchColumn, row[matchColumn])
            .update(values);
      }
    }
    return true;
  }

  @override
  Future<void> chunk(
    int chunk,
    void Function(List<Map<String, dynamic>> data) callback,
  ) async {
    var offset = 0;
    while (true) {
      final data = await _freshFromState().limit(chunk).offset(offset).get();
      if (data.isEmpty) return;
      callback(data);
      if (data.length < chunk) return;
      offset += chunk;
    }
  }

  @override
  Future<void> chunkById(
    int chunk,
    void Function(List<Map<String, dynamic>> data) callback, [
    String column = '_id',
  ]) async {
    dynamic lastId;
    while (true) {
      final query = _freshFromState().orderByAsc(column).limit(chunk);
      if (lastId != null) query.whereGreaterThan(column, lastId);
      final data = await query.get();
      if (data.isEmpty) return;
      callback(data);
      lastId = data.last[column];
      if (data.length < chunk) return;
    }
  }

  @override
  Future<void> chunkedProcess({
    required int chunkSize,
    required Future<List<Map<String, dynamic>>> Function(
      List<Map<String, dynamic>> chunk,
    )
    processor,
    String? destination,
    List<String> columns = const ['*'],
  }) async {
    var offset = 0;
    while (true) {
      final chunk = await _fresh().take(chunkSize).skip(offset).get(columns);
      if (chunk.isEmpty) return;
      final processed = await processor(chunk);
      if (destination != null && processed.isNotEmpty) {
        await DB.collection(destination).insertMany(processed);
      }
      if (chunk.length < chunkSize) return;
      offset += chunkSize;
    }
  }

  @override
  QueryBuilder collection(String collection) => table(collection);

  @override
  QueryBuilder connection([String? connection]) {
    _connectionName = connection ?? _connectionName;
    return this;
  }

  @override
  QueryBuilder crossJoin(String table, [List<dynamic> bindings = const []]) {
    return this;
  }

  @override
  QueryBuilder cumeDist({String? partitionBy, String? orderBy, String? as}) {
    return this;
  }

  @override
  QueryBuilder denseRank({String? partitionBy, String? orderBy, String? as}) {
    return this;
  }

  @override
  Future<int> count([String columns = '*']) {
    return mongoCollection.count(toSelector());
  }

  @override
  Stream<Map<String, dynamic>> cursor([int chunk = 1000]) async* {
    var offset = 0;
    while (true) {
      final rows = await _freshFromState().limit(chunk).offset(offset).get();
      if (rows.isEmpty) return;
      for (final row in rows) {
        yield row;
      }
      if (rows.length < chunk) return;
      offset += chunk;
    }
  }

  @override
  Future<bool> decrement(
    String column, [
    int amount = 1,
    Map<String, dynamic> extra = const {},
  ]) {
    return increment(column, -amount, extra);
  }

  @override
  Future<bool> delete() async {
    await mongoCollection.deleteMany(toSelector());
    return true;
  }

  @override
  Future<bool> doesntExist() async => !await exists();

  @override
  Future<void> each(void Function(Map<String, dynamic> q) callback) async {
    final rows = await get();
    for (final row in rows) {
      callback(row);
    }
  }

  @override
  Future<bool> exists() async => await first(['_id']) != null;

  @override
  Future<Map<String, dynamic>?> find(
    dynamic id, {
    String byColumnName = '_id',
    List<String> columns = const ['*'],
  }) {
    return _freshFromState()
        .whereEqualTo(byColumnName, _normalizeId(byColumnName, id))
        .first(columns);
  }

  @override
  Future<Map<String, dynamic>?> findOrFail(
    dynamic id, {
    String byColumnName = '_id',
    List<String> columns = const ['*'],
  }) async {
    final row = await find(id, byColumnName: byColumnName, columns: columns);
    if (row == null) {
      throw InvalidArgumentException('Record with id $id not found.');
    }
    return row;
  }

  @override
  Future<Map<String, dynamic>?> first([
    List<String> columns = const ['*'],
  ]) async {
    final rows = await _freshFromState().limit(1).get(columns);
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<Map<String, dynamic>?> firstOrFail([
    List<String> columns = const ['*'],
  ]) async {
    final row = await first(columns);
    if (row == null) throw InvalidArgumentException('No records found.');
    return row;
  }

  @override
  Future<Map<String, dynamic>?> firstWhere(
    String column, [
    String? operator = '=',
    dynamic value,
    List<String> columns = const ['*'],
  ]) {
    if (value == null) {
      throw InvalidArgumentException(
        'Invalid input: Value cannot be null. A valid value must be provided for the firstWhere method.',
      );
    }
    return where(column, operator ?? '=', value).first(columns);
  }

  @override
  Future<List<Map<String, dynamic>>> get([
    List<String> columns = const ['*'],
  ]) async {
    if (columns.isNotEmpty && !(columns.length == 1 && columns.first == '*')) {
      select(columns);
    }
    final selector = toSelector();
    final result = await mongoCollection.find(selector).toList();
    _applySort(result);
    final skipped = _skip == null ? result : result.skip(_skip!);
    final limited = _limit == null ? skipped : skipped.take(_limit!);
    return limited.map(_project).toList();
  }

  @override
  Map<String, dynamic> getBindings() => Map.unmodifiable(_bindings);

  @override
  QueryBuilder groupBy(List<String> groups) => this;

  @override
  QueryBuilder groupByRaw(String expression) => throw UnsupportedError(
    'groupByRaw is SQL-only. Use an aggregation pipeline on the MongoDB '
    'driver.',
  );

  @override
  QueryBuilder having(
    String column, [
    String? operator,
    dynamic value,
    String boolean = 'and',
  ]) => this;

  @override
  QueryBuilder havingBetween(
    String column,
    List<dynamic> values, {
    String boolean = 'and',
    bool not = false,
  }) => this;

  @override
  Future<bool> increment(
    String column, [
    int amount = 1,
    Map<String, dynamic> extra = const {},
  ]) async {
    final update = <String, dynamic>{
      '\$inc': {column: amount},
    };
    if (extra.isNotEmpty) update['\$set'] = extra;
    await mongoCollection.updateMany(toSelector(), update);
    return true;
  }

  @override
  Future<bool> incrementEach(
    Map<String, int> increments, [
    Map<String, dynamic> extra = const {},
  ]) async {
    final update = <String, dynamic>{'\$inc': increments};
    if (extra.isNotEmpty) update['\$set'] = extra;
    await mongoCollection.updateMany(toSelector(), update);
    return true;
  }

  @override
  QueryBuilder inRandomOrder([dynamic seed]) {
    _sort.clear();
    return this;
  }

  @override
  Future<bool> insert(Map<String, dynamic> values) async {
    _ensureNotEmpty(values, 'insert');
    await mongoCollection.insertOne(Map<String, dynamic>.from(values));
    return true;
  }

  @override
  Future insertGetId(Map<String, dynamic> values, [String? sequence]) async {
    _ensureNotEmpty(values, 'insertGetId');
    final document = Map<String, dynamic>.from(values);
    await mongoCollection.insertOne(document);
    return document['_id'];
  }

  @override
  Future<bool> insertMany(List<Map<String, dynamic>> valuesList) async {
    if (valuesList.isEmpty) {
      throw InvalidArgumentException(
        'Values list cannot be empty for insertMany operation.',
      );
    }
    await mongoCollection.insertMany(
      valuesList.map((row) => Map<String, dynamic>.from(row)).toList(),
    );
    return true;
  }

  @override
  Future<bool> insertOrIgnore(Map<String, dynamic> values) async {
    try {
      return await insert(values);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> insertUsing(List<String> columns, QueryBuilder subQuery) {
    throw UnsupportedError('insertUsing is SQL-specific and is not supported.');
  }

  @override
  QueryBuilder join(
    String table,
    String first, [
    String? operator,
    String? second,
    String type = 'INNER',
  ]) => this;

  @override
  QueryBuilder joinSub(
    QueryBuilder query,
    String as,
    String first, [
    String? operator,
    String? second,
    String type = 'INNER',
  ]) {
    return this;
  }

  @override
  QueryBuilder lag(
    String column, {
    int offset = 1,
    dynamic defaultValue,
    String? partitionBy,
    String? orderBy,
    String? as,
  }) {
    return this;
  }

  @override
  Stream<Iterable<Map<String, dynamic>>> lazy([
    int chunk = 100,
    String column = '_id',
  ]) async* {
    var offset = 0;
    while (true) {
      final rows = await _freshFromState()
          .orderByAsc(column)
          .limit(chunk)
          .offset(offset)
          .get();
      if (rows.isEmpty) return;
      yield rows;
      if (rows.length < chunk) return;
      offset += chunk;
    }
  }

  @override
  QueryBuilder latest([String column = 'created_at']) => orderByDesc(column);

  @override
  QueryBuilder leftJoin(
    String table,
    String first, [
    String? operator,
    String? second,
  ]) => this;

  @override
  QueryBuilder leftJoinSub(
    QueryBuilder query,
    String as,
    String first, [
    String? operator,
    String? second,
  ]) {
    return this;
  }

  @override
  QueryBuilder lead(
    String column, {
    int offset = 1,
    dynamic defaultValue,
    String? partitionBy,
    String? orderBy,
    String? as,
  }) {
    return this;
  }

  @override
  QueryBuilder limit(int value) {
    _limit = value;
    return this;
  }

  @override
  Future max(String column) async {
    final rows = await get([column]);
    final values = rows.map((row) => row[column]).whereType<Comparable>();
    if (values.isEmpty) return null;
    return values.reduce(
      (left, right) => left.compareTo(right) >= 0 ? left : right,
    );
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
        'Source data cannot be empty for merge operation',
      );
    }
    if (matchOn.isEmpty) {
      throw InvalidArgumentException(
        'Match columns cannot be empty for merge operation',
      );
    }
    for (final row in sourceData) {
      final values = Map<String, dynamic>.from(row);
      if (additionalValues != null) values.addAll(additionalValues);
      final update = <String, dynamic>{};
      final columns =
          updateColumns ?? values.keys.where((key) => !matchOn.contains(key));
      for (final column in columns) {
        if (values.containsKey(column)) update[column] = values[column];
      }
      await upsert(values, matchOn, update);
    }
    return true;
  }

  @override
  Future min(String column) async {
    final rows = await get([column]);
    final values = rows.map((row) => row[column]).whereType<Comparable>();
    if (values.isEmpty) return null;
    return values.reduce(
      (left, right) => left.compareTo(right) <= 0 ? left : right,
    );
  }

  @override
  QueryBuilder offset(int value) => skip(value);

  @override
  QueryBuilder orderBy(String column, [String direction = 'ASC']) {
    _sort[column] = direction.toUpperCase() == 'DESC' ? -1 : 1;
    return this;
  }

  @override
  QueryBuilder orderByRaw(String expression) => throw UnsupportedError(
    'orderByRaw is SQL-only. Use orderBy, or an aggregation pipeline on '
    'the MongoDB driver.',
  );

  @override
  QueryBuilder orderByAsc(String column) => orderBy(column);

  @override
  QueryBuilder orderByDesc(String column) => orderBy(column, 'DESC');

  @override
  QueryBuilder ntile(
    int buckets, {
    String? partitionBy,
    String? orderBy,
    String? as,
  }) {
    return this;
  }

  @override
  QueryBuilder orWhere(
    dynamic condition, [
    String operator = '=',
    dynamic value,
  ]) {
    return where(condition, operator, value, 'or');
  }

  @override
  QueryBuilder orWhereBetween(String column, List values, {bool not = false}) =>
      whereBetween(column, values, boolean: 'or', not: not);

  @override
  QueryBuilder orWhereColumn(
    String first,
    String operator,
    String secondColumn,
  ) {
    return whereColumn(first, operator, secondColumn, 'or');
  }

  @override
  QueryBuilder orWhereDate(String column, String operator, dynamic value) {
    return whereDate(column, operator, value, boolean: 'or');
  }

  @override
  QueryBuilder orWhereDay(String column, String operator, dynamic value) {
    return whereDay(column, operator, value, boolean: 'or');
  }

  @override
  QueryBuilder orWhereDoesntHave(String relation, QueryCallback callback) {
    return this;
  }

  @override
  QueryBuilder orWhereExists(QueryCallback callback, {bool not = false}) {
    return this;
  }

  @override
  QueryBuilder orWhereFullText(
    dynamic columns,
    dynamic query, [
    Map<String, dynamic> options = const {},
  ]) {
    return whereFullText(columns, query, options);
  }

  @override
  QueryBuilder orWhereHas(String relation, QueryCallback callback) => this;

  @override
  QueryBuilder orWhereHour(String column, String operator, dynamic value) {
    return whereHour(column, operator, value, boolean: 'or');
  }

  @override
  QueryBuilder orWhereIn(String column, List values, {bool not = false}) {
    return whereIn(column, values, boolean: 'or', not: not);
  }

  @override
  QueryBuilder orWhereJsonContains(
    String column,
    dynamic value, {
    bool not = false,
  }) {
    return whereJsonContains(column, value, boolean: 'or', not: not);
  }

  @override
  QueryBuilder orWhereJsonDoesntContain(String column, dynamic value) {
    return whereJsonContains(column, value, boolean: 'or', not: true);
  }

  @override
  QueryBuilder orWhereJsonLength(
    String column,
    String operator,
    dynamic value,
  ) {
    return whereJsonLength(column, operator, value, boolean: 'or');
  }

  @override
  QueryBuilder orWhereLike(
    String column,
    dynamic value, {
    bool caseSensitive = false,
  }) {
    return whereLike(
      column,
      value,
      caseSensitive: caseSensitive,
      boolean: 'or',
    );
  }

  @override
  QueryBuilder orWhereMonth(String column, String operator, dynamic value) {
    return whereMonth(column, operator, value, boolean: 'or');
  }

  @override
  QueryBuilder orWhereNotBetween(String column, List values) {
    return whereBetween(column, values, boolean: 'or', not: true);
  }

  @override
  QueryBuilder orWhereNotExists(QueryCallback callback) => this;

  @override
  QueryBuilder orWhereNotIn(String column, dynamic values) {
    return whereIn(column, values as List, boolean: 'or', not: true);
  }

  @override
  QueryBuilder orWhereNotLike(
    String column,
    dynamic value, {
    bool caseSensitive = false,
    String boolean = 'and',
  }) {
    return whereNotLike(
      column,
      value,
      caseSensitive: caseSensitive,
      boolean: 'or',
    );
  }

  @override
  QueryBuilder orWhereNotNull(String column) {
    return whereNull(column, boolean: 'or', not: true);
  }

  @override
  QueryBuilder orWhereNull(String column) {
    return whereNull(column, boolean: 'or');
  }

  @override
  QueryBuilder orWhereRaw(String sql, [List<dynamic> rawBindings = const []]) {
    throw UnsupportedError('Use rawWhere() with a MongoDB selector map.');
  }

  @override
  QueryBuilder orWhereRowValues(
    List<String> columns,
    String operator,
    List<dynamic> values,
  ) {
    return whereRowValues(columns, operator, values, boolean: 'or');
  }

  @override
  QueryBuilder orWhereTime(String column, String operator, dynamic value) {
    return whereTime(column, operator, value, boolean: 'or');
  }

  @override
  QueryBuilder orWhereYear(String column, String operator, dynamic value) {
    return whereYear(column, operator, value, boolean: 'or');
  }

  @override
  Future<Map<String, dynamic>> paginate({
    int perPage = 15,
    List<String> columns = const ['*'],
    String? pageName,
    int? page,
  }) async {
    final currentPage = page ?? getParam<int>(pageName ?? 'page', 1)!;
    final total = await count();
    final lastPage = (total / perPage).ceil();
    final offset = (currentPage - 1) * perPage;
    final pageData = await _freshFromState()
        .take(perPage)
        .skip(offset)
        .get(columns);
    return PaginatedResult(
      data: pageData,
      currentPage: currentPage,
      perPage: perPage,
      total: total,
      lastPage: lastPage,
      isFirst: currentPage == 1,
      isLast: currentPage == lastPage,
      hasMore: currentPage < lastPage,
    ).toMap();
  }

  @override
  QueryBuilder percentRank({String? partitionBy, String? orderBy, String? as}) {
    return this;
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
        'Data cannot be empty for parallel bulk insert operation',
      );
    }
    final safeParallelism = parallelism < 1 ? 1 : parallelism;
    final chunkSize = (data.length / safeParallelism).ceil();
    final tasks = <Future<bool>>[];
    for (var i = 0; i < data.length; i += chunkSize) {
      tasks.add(
        bulkInsert(
          data.skip(i).take(chunkSize).toList(),
          batchSize: batchSize,
          conflictAction: conflictAction,
          conflictColumns: conflictColumns,
        ),
      );
    }
    final results = await Future.wait(tasks);
    return results.every((result) => result);
  }

  @override
  Future pluck(String column, [String? key]) async {
    final rows = await get(key == null ? [column] : [column, key]);
    if (key == null) return rows.map((row) => row[column]).toList();
    return {for (final row in rows) row[key]: row[column]};
  }

  @override
  QueryBuilder rawWhere(Map<String, dynamic> selector) {
    _append(selector);
    return this;
  }

  @override
  QueryBuilder reorder([String? column, String? direction]) {
    _sort.clear();
    if (column != null) orderBy(column, direction ?? 'ASC');
    return this;
  }

  @override
  QueryBuilder rightJoin(
    String table,
    String first, [
    String? operator,
    String? second,
  ]) => this;

  @override
  QueryBuilder rowNumber({String? partitionBy, String? orderBy, String? as}) {
    return this;
  }

  @override
  QueryBuilder rank({String? partitionBy, String? orderBy, String? as}) {
    return this;
  }

  @override
  QueryBuilder select([List<String> columns = const ['*']]) {
    _columns = List<String>.from(columns);
    return this;
  }

  @override
  QueryBuilder selectRaw(String query, [List bindings = const []]) {
    return addSelect([query]);
  }

  @override
  QueryBuilder selectSub(QueryBuilder subQuery, String as) {
    return addSelect([as]);
  }

  @override
  Future<Map<String, dynamic>> simplePaginate([
    int perPage = 15,
    List<String> columns = const ['*'],
    String? pageName,
    int? page,
  ]) async {
    final currentPage = page ?? getParam<int>(pageName ?? 'page', 1)!;
    final total = await count();
    final lastPage = (total / perPage).ceil();
    final offset = (currentPage - 1) * perPage;
    final pageData = await _freshFromState()
        .take(perPage)
        .skip(offset)
        .get(columns);
    return {
      'data': pageData,
      'current_page': currentPage,
      'per_page': perPage,
      'total': total,
      'last_page': lastPage,
    };
  }

  @override
  QueryBuilder skip(int value) {
    _skip = value;
    return this;
  }

  @override
  Future<num> sum(String column) async {
    final values = await _numericValues(column);
    return values.fold<num>(0, (total, value) => total + value);
  }

  @override
  QueryBuilder table(String table, [String? as]) {
    _collectionName = table;
    _collection = DB.collection(table).mongoCollection;
    return this;
  }

  @override
  QueryBuilder take(int value) => limit(value);

  @override
  Map<String, dynamic> toSelector() {
    final selector = <String, dynamic>{};
    if (_andFilters.isNotEmpty) {
      selector.addAll(_mergeAnd(_andFilters));
    }
    if (_orFilters.isNotEmpty) {
      selector['\$or'] = _orFilters;
    }
    return selector;
  }

  @override
  String toRawSql() => toSelector().toString();

  @override
  String toSql() => toSelector().toString();

  @override
  Future<bool> transactionalBulkOperation(Future<bool> Function() action) {
    return action();
  }

  @override
  QueryBuilder union(QueryBuilder query) {
    return this;
  }

  @override
  QueryBuilder unionAll(QueryBuilder query) {
    return this;
  }

  @override
  Future<bool> truncate({bool force = false}) async {
    await mongoCollection.deleteMany({});
    return true;
  }

  @override
  Future<bool> update(Map<String, dynamic> values) async {
    _ensureNotEmpty(values, 'update');
    await mongoCollection.updateMany(toSelector(), {'\$set': values});
    return true;
  }

  @override
  Future<bool> updateMany(
    List<Map<String, dynamic>> updates,
    String column,
  ) async {
    if (updates.isEmpty) return false;
    for (final row in updates) {
      if (!row.containsKey(column)) continue;
      final values = Map<String, dynamic>.from(row)..remove(column);
      await _freshFromState().whereEqualTo(column, row[column]).update(values);
    }
    return true;
  }

  @override
  Future<bool> updateOrInsert(
    Map<String, dynamic> search,
    Map<String, dynamic> update,
  ) {
    final values = <String, dynamic>{...search, ...update};
    return upsert(values, search.keys.toList(), update);
  }

  @override
  Future<bool> upsert(
    Map<String, dynamic> values,
    List<String> uniqueBy, [
    Map<String, dynamic>? update,
  ]) async {
    _ensureNotEmpty(values, 'upsert');
    if (uniqueBy.isEmpty) {
      throw InvalidArgumentException('Unique columns cannot be empty.');
    }
    final search = {for (final key in uniqueBy) key: values[key]};
    final existing = await _fresh().rawWhere(search).first(['_id']);
    if (existing == null) {
      return insert(values);
    }
    final updateValues = update ?? Map<String, dynamic>.from(values)
      ..removeWhere((key, _) => uniqueBy.contains(key));
    return _fresh().whereEqualTo('_id', existing['_id']).update(updateValues);
  }

  @override
  Future value(String column) async {
    final row = await first([column]);
    return row?[column];
  }

  @override
  QueryBuilder where(
    dynamic condition, [
    String operator = '=',
    dynamic value,
    String boolean = 'and',
  ]) {
    if (condition is QueryCallback) {
      final nested = MongoQueryBuilderImpl(_collection);
      condition(nested);
      _append(nested.toSelector(), boolean: boolean);
      return this;
    }
    if (condition is Map<String, dynamic>) {
      _append(condition, boolean: boolean);
      return this;
    }
    if (condition is! String) {
      throw InvalidArgumentException(
        'Invalid argument type for condition. Expected String, Map, or QueryCallback.',
      );
    }
    _bindings['p${_bindings.length + 1}'] = value;
    _append(_operatorSelector(condition, operator, value), boolean: boolean);
    return this;
  }

  @override
  QueryBuilder whereAfterToday(String column, {String boolean = 'and'}) {
    return whereGreaterThan(column, _todayEnd(), boolean);
  }

  @override
  QueryBuilder whereAll(
    String column,
    List<dynamic> values, {
    String boolean = 'and',
  }) {
    return where(column, 'all', values, boolean);
  }

  @override
  QueryBuilder whereAny(
    String column,
    List<dynamic> values, {
    String boolean = 'and',
  }) {
    return whereIn(column, values, boolean: boolean);
  }

  @override
  QueryBuilder whereBeforeToday(String column, {String boolean = 'and'}) {
    return whereLessThan(column, _todayStart(), boolean);
  }

  @override
  QueryBuilder whereBetween(
    String column,
    List values, {
    String boolean = 'and',
    bool not = false,
  }) {
    if (values.length < 2) {
      throw InvalidArgumentException(
        'The list of values must contain at least two items.',
      );
    }
    final selector = not
        ? {
            '\$or': [
              {
                column: {'\$lt': values[0]},
              },
              {
                column: {'\$gt': values[1]},
              },
            ],
          }
        : {
            column: {'\$gte': values[0], '\$lte': values[1]},
          };
    _append(selector, boolean: boolean);
    return this;
  }

  @override
  QueryBuilder whereBetweenColumns(
    String column,
    List<String> columns, {
    String boolean = 'and',
  }) {
    if (columns.length < 2) {
      throw InvalidArgumentException(
        'At least two columns must be provided for whereBetweenColumns.',
      );
    }
    _append({
      '\$expr': {
        '\$and': [
          {
            '\$gte': ['\$$column', '\$${columns[0]}'],
          },
          {
            '\$lte': ['\$$column', '\$${columns[1]}'],
          },
        ],
      },
    }, boolean: boolean);
    return this;
  }

  @override
  QueryBuilder whereColumn(
    String firstColumn,
    String operator,
    String secondColumn, [
    String boolean = 'and',
  ]) {
    return rawWhere({
      '\$expr': {
        _exprOperator(operator): ['\$$firstColumn', '\$$secondColumn'],
      },
    });
  }

  @override
  QueryBuilder whereDate(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  }) {
    return where(column, operator, value, boolean);
  }

  @override
  QueryBuilder whereDay(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  }) {
    return where(column, operator, value, boolean);
  }

  @override
  QueryBuilder whereDoesntHave(
    String relation,
    QueryCallback callback, {
    String boolean = 'and',
  }) => this;

  @override
  QueryBuilder whereEqualTo(
    dynamic condition, [
    dynamic value,
    String boolean = 'and',
  ]) => where(condition, '=', value, boolean);

  @override
  QueryBuilder whereExists(
    QueryCallback callback, {
    String boolean = 'and',
    bool not = false,
  }) => this;

  @override
  QueryBuilder whereFullText(
    dynamic columns,
    dynamic query, [
    Map<String, dynamic> options = const {},
  ]) {
    final fields = columns is List ? columns : [columns];
    final pattern = RegExp(
      RegExp.escape(query.toString()),
      caseSensitive: false,
    );
    final selector = {
      '\$or': [
        for (final field in fields) {field.toString(): pattern},
      ],
    };
    _append(selector);
    return this;
  }

  @override
  QueryBuilder whereFuture(String column, {String boolean = 'and'}) {
    return whereGreaterThan(column, DateTime.now(), boolean);
  }

  @override
  QueryBuilder whereGreaterThan(
    dynamic condition, [
    dynamic value,
    String boolean = 'and',
  ]) => where(condition, '>', value, boolean);

  @override
  QueryBuilder whereGreaterThanOrEqualTo(
    dynamic condition, [
    dynamic value,
    String boolean = 'and',
  ]) => where(condition, '>=', value, boolean);

  @override
  QueryBuilder whereHas(
    String relation,
    QueryCallback callback, {
    String boolean = 'and',
  }) => this;

  @override
  QueryBuilder whereHour(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  }) {
    return where(column, operator, value, boolean);
  }

  @override
  QueryBuilder whereIn(
    String column,
    List values, {
    String boolean = 'and',
    bool not = false,
  }) {
    _append({
      column: {not ? '\$nin' : '\$in': values},
    }, boolean: boolean);
    return this;
  }

  @override
  QueryBuilder whereJsonContains(
    String column,
    dynamic value, {
    String boolean = 'and',
    bool not = false,
  }) {
    return where(column, not ? '!=' : '=', value, boolean);
  }

  @override
  QueryBuilder whereJsonDoesntContain(
    String column,
    dynamic value, {
    String boolean = 'and',
  }) {
    return whereJsonContains(column, value, boolean: boolean, not: true);
  }

  @override
  QueryBuilder whereJsonLength(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  }) {
    _append({
      '\$expr': {
        _exprOperator(operator): [
          {'\$size': '\$$column'},
          value,
        ],
      },
    }, boolean: boolean);
    return this;
  }

  @override
  QueryBuilder whereLessThan(
    dynamic condition, [
    dynamic value,
    String boolean = 'and',
  ]) => where(condition, '<', value, boolean);

  @override
  QueryBuilder whereLessThanOrEqualTo(
    dynamic condition, [
    dynamic value,
    String boolean = 'and',
  ]) => where(condition, '<=', value, boolean);

  @override
  QueryBuilder whereLike(
    String column,
    dynamic value, {
    bool caseSensitive = false,
    String boolean = 'and',
  }) {
    final source = value.toString().replaceAll('%', '.*');
    _append({
      column: RegExp(source, caseSensitive: caseSensitive),
    }, boolean: boolean);
    return this;
  }

  @override
  QueryBuilder whereMonth(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  }) {
    return where(column, operator, value, boolean);
  }

  @override
  QueryBuilder whereNone(
    String column,
    List<dynamic> values, {
    String boolean = 'and',
  }) {
    return whereIn(column, values, boolean: boolean, not: true);
  }

  @override
  QueryBuilder whereNotBetween(
    String column,
    List values, {
    String boolean = 'and',
  }) {
    return whereBetween(column, values, boolean: boolean, not: true);
  }

  @override
  QueryBuilder whereNotBetweenColumns(
    String column,
    List<String> columns, {
    String boolean = 'and',
  }) {
    if (columns.length < 2) {
      throw InvalidArgumentException(
        'At least two columns must be provided for whereNotBetweenColumns.',
      );
    }
    _append({
      '\$expr': {
        '\$or': [
          {
            '\$lt': ['\$$column', '\$${columns[0]}'],
          },
          {
            '\$gt': ['\$$column', '\$${columns[1]}'],
          },
        ],
      },
    }, boolean: boolean);
    return this;
  }

  @override
  QueryBuilder whereNotEqualTo(
    dynamic condition, [
    dynamic value,
    String boolean = 'and',
  ]) => where(condition, '!=', value, boolean);

  @override
  QueryBuilder whereNotExists(
    QueryCallback callback, {
    String boolean = 'and',
  }) {
    return whereExists(callback, boolean: boolean, not: true);
  }

  @override
  QueryBuilder whereNotIn(
    String column,
    dynamic values, {
    String boolean = 'and',
  }) {
    return whereIn(column, values as List, boolean: boolean, not: true);
  }

  @override
  QueryBuilder whereNotLike(
    String column,
    dynamic value, {
    bool caseSensitive = false,
    String boolean = 'and',
  }) {
    final source = value.toString().replaceAll('%', '.*');
    _append({
      column: {'\$not': RegExp(source, caseSensitive: caseSensitive)},
    }, boolean: boolean);
    return this;
  }

  @override
  QueryBuilder whereNotNull(String column, {String boolean = 'and'}) {
    return whereNull(column, boolean: boolean, not: true);
  }

  @override
  QueryBuilder whereNowOrFuture(String column, {String boolean = 'and'}) {
    return whereGreaterThanOrEqualTo(column, DateTime.now(), boolean);
  }

  @override
  QueryBuilder whereNowOrPast(String column, {String boolean = 'and'}) {
    return whereLessThanOrEqualTo(column, DateTime.now(), boolean);
  }

  @override
  QueryBuilder whereNull(
    String column, {
    String boolean = 'and',
    bool not = false,
  }) {
    _append({
      column: not ? {'\$ne': null} : null,
    }, boolean: boolean);
    return this;
  }

  @override
  QueryBuilder wherePast(String column, {String boolean = 'and'}) {
    return whereLessThan(column, DateTime.now(), boolean);
  }

  @override
  QueryBuilder whereRaw(
    String sql, [
    List<dynamic> rawBindings = const [],
    String boolean = 'and',
  ]) {
    throw UnsupportedError('Use rawWhere() with a MongoDB selector map.');
  }

  @override
  QueryBuilder whereRowValues(
    List<String> columns,
    String operator,
    List<dynamic> values, {
    String boolean = 'and',
  }) {
    if (columns.length != values.length) {
      throw InvalidArgumentException(
        'The number of columns and values must be equal.',
      );
    }
    _append({
      '\$expr': {
        '\$and': [
          for (var i = 0; i < columns.length; i++)
            {
              _exprOperator(operator): ['\$${columns[i]}', values[i]],
            },
        ],
      },
    }, boolean: boolean);
    return this;
  }

  @override
  QueryBuilder whereTime(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  }) {
    return where(column, operator, value, boolean);
  }

  @override
  QueryBuilder whereToday(String column, {String boolean = 'and'}) {
    return whereBetween(column, [_todayStart(), _todayEnd()], boolean: boolean);
  }

  @override
  QueryBuilder whereTodayOrAfter(String column, {String boolean = 'and'}) {
    return whereGreaterThanOrEqualTo(column, _todayStart(), boolean);
  }

  @override
  QueryBuilder whereTodayOrBefore(String column, {String boolean = 'and'}) {
    return whereLessThanOrEqualTo(column, _todayEnd(), boolean);
  }

  @override
  QueryBuilder whereYear(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  }) {
    return where(column, operator, value, boolean);
  }

  @override
  QueryBuilder withSoftDeletes([String column = 'deleted_at']) {
    return whereNull(column);
  }

  @override
  QueryBuilder withCte(
    String name,
    QueryBuilder query, {
    List<String>? columns,
  }) {
    return this;
  }

  @override
  QueryBuilder withMaterialized(
    String name,
    QueryBuilder query, {
    List<String>? columns,
  }) {
    return this;
  }

  @override
  QueryBuilder withMultiple(Map<String, QueryBuilder> queries) {
    return this;
  }

  @override
  QueryBuilder withNotMaterialized(
    String name,
    QueryBuilder query, {
    List<String>? columns,
  }) {
    return this;
  }

  @override
  QueryBuilder withRecursive(
    String name,
    QueryBuilder query, {
    List<String>? columns,
  }) {
    return this;
  }

  @override
  QueryBuilder windowAvg(
    String column, {
    String? partitionBy,
    String? orderBy,
    String? as,
  }) {
    return this;
  }

  @override
  QueryBuilder windowCount(
    String column, {
    String? partitionBy,
    String? orderBy,
    String? as,
  }) {
    return this;
  }

  @override
  QueryBuilder windowMax(
    String column, {
    String? partitionBy,
    String? orderBy,
    String? as,
  }) {
    return this;
  }

  @override
  QueryBuilder windowMin(
    String column, {
    String? partitionBy,
    String? orderBy,
    String? as,
  }) {
    return this;
  }

  @override
  QueryBuilder windowSum(
    String column, {
    String? partitionBy,
    String? orderBy,
    String? as,
  }) {
    return this;
  }

  @override
  QueryBuilder firstValue(
    String column, {
    String? partitionBy,
    String? orderBy,
    String? as,
  }) {
    return this;
  }

  @override
  QueryBuilder lastValue(
    String column, {
    String? partitionBy,
    String? orderBy,
    String? as,
  }) {
    return this;
  }

  void _append(Map<String, dynamic> selector, {String boolean = 'and'}) {
    if (boolean.toLowerCase() == 'or') {
      _orFilters.add(selector);
      return;
    }
    _andFilters.add(selector);
  }

  void _applySort(List<Map<String, dynamic>> rows) {
    if (_sort.isEmpty) return;
    rows.sort((left, right) {
      for (final entry in _sort.entries) {
        final leftValue = left[entry.key];
        final rightValue = right[entry.key];
        if (leftValue is Comparable && rightValue is Comparable) {
          final compared = leftValue.compareTo(rightValue);
          if (compared != 0) return compared * entry.value;
        }
      }
      return 0;
    });
  }

  void _ensureNotEmpty(Map<String, dynamic> values, String operation) {
    if (values.isEmpty) {
      throw InvalidArgumentException(
        'Values map cannot be empty for $operation operation.',
      );
    }
  }

  String _exprOperator(String operator) {
    return switch (operator) {
      '=' || '==' => '\$eq',
      '!=' || '<>' => '\$ne',
      '>' => '\$gt',
      '>=' => '\$gte',
      '<' => '\$lt',
      '<=' => '\$lte',
      _ => throw InvalidArgumentException(
        'Invalid MongoDB operator: $operator',
      ),
    };
  }

  MongoQueryBuilderImpl _fresh() {
    return MongoQueryBuilderImpl(_collection)
      .._collectionName = _collectionName
      .._connectionName = _connectionName;
  }

  MongoQueryBuilderImpl _freshFromState() {
    final query = _fresh()
      .._columns = List<String>.from(_columns)
      .._limit = _limit
      .._skip = _skip
      .._sort.addAll(_sort)
      .._andFilters.addAll(_andFilters.map(Map<String, dynamic>.from))
      .._orFilters.addAll(_orFilters.map(Map<String, dynamic>.from))
      .._bindings.addAll(_bindings);
    return query;
  }

  Map<String, dynamic> _mergeAnd(List<Map<String, dynamic>> filters) {
    if (filters.length == 1) return Map<String, dynamic>.from(filters.first);
    return {'\$and': filters};
  }

  dynamic _normalizeId(String column, dynamic value) {
    if (column != '_id' || value is! String) return value;
    return ObjectId.tryParse(value) ?? value;
  }

  Future<List<num>> _numericValues(String column) async {
    final rows = await get([column]);
    return rows
        .map((row) => row[column])
        .whereType<num>()
        .toList(growable: false);
  }

  Map<String, dynamic> _operatorSelector(
    String column,
    String operator,
    dynamic value,
  ) {
    return switch (operator.toUpperCase()) {
      '=' || '==' => {column: _normalizeId(column, value)},
      '!=' || '<>' => {
        column: {'\$ne': _normalizeId(column, value)},
      },
      '>' => {
        column: {'\$gt': value},
      },
      '>=' => {
        column: {'\$gte': value},
      },
      '<' => {
        column: {'\$lt': value},
      },
      '<=' => {
        column: {'\$lte': value},
      },
      'LIKE' || 'ILIKE' => {
        column: RegExp(
          value.toString().replaceAll('%', '.*'),
          caseSensitive: operator.toUpperCase() == 'LIKE',
        ),
      },
      'NOT LIKE' || 'NOT ILIKE' => {
        column: {
          '\$not': RegExp(
            value.toString().replaceAll('%', '.*'),
            caseSensitive: operator.toUpperCase() == 'NOT LIKE',
          ),
        },
      },
      'ALL' => {
        column: {'\$all': value},
      },
      _ => throw InvalidArgumentException(
        'Invalid MongoDB operator: $operator',
      ),
    };
  }

  Map<String, dynamic> _project(Map<String, dynamic> row) {
    if (_columns.isEmpty || (_columns.length == 1 && _columns.first == '*')) {
      return Map<String, dynamic>.from(row);
    }
    return {
      for (final column in _columns)
        if (row.containsKey(column)) column: row[column],
    };
  }

  DateTime _todayEnd() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  DateTime _todayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
