import 'package:meta/meta.dart';
import 'package:vania/database.dart';
import 'package:vania/src/database/utils/singularize.dart';
import 'package:vania/foundation.dart'
    show InvalidArgumentException, Pluralize, getParam, toSnakeCase;

abstract class Model extends QueryBuilderImpl {
  @protected
  Map<String, dynamic> attributes = {};
  final Map<String, Relation> _relations = {};
  List<_RelationQuery> _withRelation = [];
  String get defaultConnection => _connection;

  String _connection = 'mysql';
  @protected
  String get createdAt => 'created_at';
  @protected
  String get deletedAt => 'deleted_at';
  @protected
  String get updatedAt => 'updated_at';
  @protected
  List<String> get fillable => [];
  @protected
  List<String> get guarded => [];

  /// Columns stripped from the rows the model hands back.
  ///
  /// This covers the row-returning reads — `get`, `first`, `find`,
  /// `paginate`, `chunk` — and `toJson`. `pluck` and `value` name a single
  /// column outright, so rather than strip it they throw when handed a
  /// hidden one.
  @protected
  List<String> get hidden => [];

  static final Map<Type, Set<String>> _hiddenCache = {};

  Set<String> get _hiddenColumns =>
      _hiddenCache.putIfAbsent(runtimeType, () => hidden.toSet());

  /// Removes the columns listed in [hidden] from every row.
  ///
  /// Always called *after* relations are resolved: a hidden column can also
  /// be the local/foreign key an eager load matches on, and stripping it
  /// first would silently return empty relations.
  List<Map<String, dynamic>> _stripHidden(List<Map<String, dynamic>> rows) {
    final columns = _hiddenColumns;
    if (columns.isEmpty) return rows;
    for (final row in rows) {
      row.removeWhere((key, _) => columns.contains(key));
    }
    return rows;
  }

  @protected
  bool get incrementing => true;
  @protected
  String get keyType => 'int';
  @protected
  String get primaryKey => 'id';

  @protected
  String? _table;

  Model get query =>
      connection(defaultConnection).table('$tablePrefix$tableName') as Model;

  @protected
  bool get softDeletes => false;

  @protected
  String get tablePrefix => '';

  @protected
  @override
  String get getTable => _table ?? tableName;

  static final Map<Type, String> _tableNameCache = {};

  @protected
  String get tableName => _tableNameCache.putIfAbsent(
    runtimeType,
    () => toSnakeCase(Pluralize().make(runtimeType.toString())).toLowerCase(),
  );

  set tableName(String table) {
    _table = table;
  }

  @protected
  bool get timestamps => true;

  bool _relationsRegistered = false;

  /// Override this method to define model relationships
  /// This method is called automatically when include() is used
  void registerRelations() {}

  /// The conventional foreign-key column for a model type: `UserProfile`
  /// becomes `user_profile_id`, matching how [tableName] snake-cases.
  static String _foreignKeyFor(Type type) =>
      '${toSnakeCase(type.toString())}_id';

  @override
  Future<num> avg(String column) async {
    if (softDeletes) {
      whereNull(deletedAt);
    }
    return super.avg(column);
  }

  void belongsTo(
    String name,
    Model model, {
    String? foreignKey,
    String localKey = 'id',
  }) {
    _relations.addEntries([
      MapEntry(
        name,
        BelongsTo(
          related: model,
          parent: this,
          foreignKey: foreignKey ?? _foreignKeyFor(model.runtimeType),
          localKey: localKey,
        ),
      ),
    ]);
  }

  void belongsToMany(
    String name,
    Model model, {
    String? pivotTable,
    required parentPivotKey,
    required relatedPivotKey,
    parentLocalKey = 'id',
    relatedLocalKey = 'id',
  }) {
    _relations.addEntries([
      MapEntry(
        name,
        BelongsToMany(
          related: model,
          parent: this,
          pivotTable:
              pivotTable ??
              '${Singularize.make(toSnakeCase(model.runtimeType.toString()))}_${Singularize.make(toSnakeCase(runtimeType.toString()))}',
          parentPivotKey: parentPivotKey,
          relatedPivotKey: relatedPivotKey,
          parentLocalKey: parentLocalKey,
          relatedLocalKey: relatedLocalKey,
        ),
      ),
    ]);
  }

  @override
  Future<void> chunk(
    int chunk,
    void Function(List<Map<String, dynamic>> data) callback,
  ) async {
    if (softDeletes) {
      whereNull(deletedAt);
    }
    super.chunk(chunk, (List<Map<String, dynamic>> data) async {
      callback(_stripHidden(await _loadRelations(data)));
    });
  }

  @override
  Future<void> chunkById(
    int chunk,
    void Function(List<Map<String, dynamic>> data) callback, [
    String column = 'id',
  ]) async {
    if (softDeletes) {
      whereNull(deletedAt);
    }
    super.chunkById(chunk, (List<Map<String, dynamic>> data) async {
      callback(_stripHidden(await _loadRelations(data)));
    }, column);
  }

  @override
  Model connection([String? connection]) {
    _setdefaultConnection(connection ?? 'mysql');
    return this;
  }

  @override
  Future<int> count([String columns = '*']) async {
    if (softDeletes) {
      whereNull(deletedAt);
    }
    return super.count(columns);
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> values) async {
    if (timestamps) {
      values[createdAt] = DateTime.now();
      values[updatedAt] = DateTime.now();
    }

    final id = await insertGetId(values);
    final result = await find(id);
    return result!;
  }

  @override
  Future<bool> delete() async {
    if (softDeletes) {
      final now = DateTime.now();
      return super.update({deletedAt: now, updatedAt: now});
    }
    return super.delete();
  }

  @override
  Future<bool> doesntExist() async {
    if (softDeletes) {
      whereNull(deletedAt);
    }
    return super.doesntExist();
  }

  @override
  Future<bool> exists() async {
    if (softDeletes) {
      whereNull(deletedAt);
    }
    return super.exists();
  }

  Model fill() {
    for (var key in attributes.keys) {
      if (fillable.contains(key) && !guarded.contains(key)) {
        setAttribute(key, attributes[key]);
      }
    }
    return this;
  }

  @override
  Future<Map<String, dynamic>?> find(
    dynamic id, {
    String? byColumnName,
    List<String> columns = const ['*'],
  }) async {
    if (softDeletes) {
      whereNull(deletedAt);
    }
    Map<String, dynamic>? result = await super.find(
      id,
      byColumnName: byColumnName ?? primaryKey,
      columns: columns,
    );
    attributes = Map.from(result ?? {});

    if (result == null) {
      return null;
    }
    return _stripHidden(await _loadRelations([result])).first;
  }

  @override
  Future<Map<String, dynamic>?> findOrFail(
    id, {
    String? byColumnName,
    List<String> columns = const ['*'],
  }) async {
    var result = await find(
      id,
      byColumnName: byColumnName ?? primaryKey,
      columns: columns,
    );
    if (result == null) {
      throw InvalidArgumentException("Record with id $id not found.");
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>?> first([
    List<String> columns = const ['*'],
  ]) async {
    if (softDeletes) {
      whereNull(deletedAt);
    }

    super.limit(1).toSql();
    final result = await super.first(columns);
    attributes = Map.from(result ?? {});

    if (result == null) {
      return null;
    }
    return _stripHidden(await _loadRelations([result])).first;
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
    where(column, operator ?? '=', value);
    return await first(columns);
  }

  @override
  Future<List<Map<String, dynamic>>> get([
    List<String> columns = const ['*'],
  ]) async {
    try {
      if (softDeletes) {
        whereNull(deletedAt);
      }
      List<Map<String, dynamic>> result = await super.get(columns);

      return _stripHidden(await _loadRelations(result));
    } catch (e) {
      throw Exception(e);
    }
  }

  dynamic getAttribute(String key) {
    return attributes[key];
  }

  dynamic getKey() {
    return attributes[primaryKey];
  }

  bool hasAttribute(String key) {
    return attributes.containsKey(key);
  }

  void hasMany(
    String name,
    Model model, {
    String? foreignKey,
    String localKey = 'id',
  }) {
    _relations.addEntries([
      MapEntry(
        name,
        HasMany(
          related: model,
          parent: this,
          foreignKey: foreignKey ?? _foreignKeyFor(runtimeType),
          localKey: localKey,
        ),
      ),
    ]);
  }

  void hasOne(
    String name,
    Model model, {
    String? foreignKey,
    String localKey = 'id',
  }) {
    _relations.addEntries([
      MapEntry(
        name,
        HasOne(
          related: model,
          parent: this,
          foreignKey: foreignKey ?? _foreignKeyFor(runtimeType),
          localKey: localKey,
        ),
      ),
    ]);
  }

  @override
  Future<bool> insert(Map<String, dynamic> values) async {
    _validateFieldsForAssignment(values);

    await super.insert(values);
    return Future.value(true);
  }

  @override
  Future insertGetId(Map<String, dynamic> values, [String? sequence]) async {
    _validateFieldsForAssignment(values);

    final id = await super.insertGetId(values, sequence);
    attributes[primaryKey] = id;

    return id;
  }

  bool is_(Model? model) {
    if (model == null) return false;
    return model.getKey() == getKey() && model.getTable == getTable;
  }

  @override
  Future max(String column) async {
    if (softDeletes) {
      whereNull(deletedAt);
    }
    return super.max(column);
  }

  @override
  Future min(String column) async {
    if (softDeletes) {
      whereNull(deletedAt);
    }
    return super.min(column);
  }

  void morphedByMany(
    String name,
    Model model, {
    required String morphKey,
    required String morphType,
    required String type,
    required String pivotTable,
    required String relatedMorphKey,
    String localKey = 'id',
  }) {
    _relations.addEntries([
      MapEntry(
        name,
        MorphedByMany(
          parent: this,
          related: model,
          morphKey: morphKey,
          morphType: morphType,
          pivotTable: pivotTable,
          relatedMorphKey: relatedMorphKey,
          type: type,
          localKey: localKey,
        ),
      ),
    ]);
  }

  void morphMany(
    String name,
    Model model, {
    required String morphKey,
    required String morphType,
    required String type,
    String localKey = 'id',
  }) {
    _relations.addEntries([
      MapEntry(
        name,
        MorphMany(
          parent: this,
          related: model,
          morphKey: morphKey,
          morphType: morphType,
          type: type,
          localKey: localKey,
        ),
      ),
    ]);
  }

  void morphOne(
    String name,
    Model model, {
    required String morphKey,
    required String morphType,
    required String type,
    String localKey = 'id',
  }) {
    _relations.addEntries([
      MapEntry(
        name,
        MorphOne(
          parent: this,
          related: model,
          morphKey: morphKey,
          morphType: morphType,
          type: type,
          localKey: localKey,
        ),
      ),
    ]);
  }

  void morphTo(
    String name,
    Model model, {
    required String morphKey,
    required String morphType,
    required String type,
    String localKey = 'id',
  }) {
    _relations.addEntries([
      MapEntry(
        name,
        MorphTo(
          parent: this,
          related: model,
          morphKey: morphKey,
          morphType: morphType,
          type: type,
          localKey: localKey,
        ),
      ),
    ]);
  }

  void morphToMany(
    String name,
    Model model, {
    required String morphKey,
    required String morphType,
    required String type,
    required String pivotTable,
    required String relatedMorphKey,
    String localKey = 'id',
  }) {
    _relations.addEntries([
      MapEntry(
        name,
        MorphToMany(
          parent: this,
          related: model,
          morphKey: morphKey,
          morphType: morphType,
          pivotTable: pivotTable,
          relatedMorphKey: relatedMorphKey,
          type: type,
          localKey: localKey,
        ),
      ),
    ]);
  }

  @override
  Future<Map<String, dynamic>> paginate({
    int perPage = 15,
    List<String> columns = const ['*'],
    String? pageName,
    int? page,
  }) async {
    int currentPage = page ?? getParam<int>('page', 1)!;
    int total = await count();
    final lastPage = (total / perPage).ceil();
    final offset = (currentPage - 1) * perPage;
    super.take(perPage).skip(offset);
    final pageData = await get();
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
      hasMore: hasMore,
    ).toMap();
  }

  @override
  Future pluck(String column, [String? key]) async {
    _rejectHidden(column);
    if (key != null) {
      _rejectHidden(key);
    }
    if (softDeletes) {
      whereNull(deletedAt);
    }
    return super.pluck(column, key);
  }

  @override
  void resetQuery() {
    super.resetQuery();
    _withRelation = [];
  }

  void setAttribute(String key, dynamic value) {
    attributes[key] = value;
  }

  @override
  Future<Map<String, dynamic>> simplePaginate([
    int perPage = 15,
    List<String> columns = const ['*'],
    String? pageName,
    int? page,
  ]) async {
    int currentPage = page ?? getParam<int>('page', 1)!;
    int total = await count();
    final lastPage = (total / perPage).ceil();
    final offset = (currentPage - 1) * perPage;
    super.take(perPage).skip(offset);
    final pageData = await get();

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
    if (softDeletes) {
      whereNull(deletedAt);
    }
    return super.sum(column);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = Map.from(attributes);
    result.removeWhere((key, _) => _hiddenColumns.contains(key));
    return result;
  }

  @override
  Future<bool> update(Map<String, dynamic> values) async {
    if (values.isEmpty) {
      throw InvalidArgumentException('Update values cannot be empty');
    }

    _validateFieldsForAssignment(values);
    if (timestamps) {
      values[updatedAt] = DateTime.now();
    }
    return super.update(values);
  }

  @override
  Future<bool> updateMany(
    List<Map<String, dynamic>> updates,
    String column,
  ) async {
    if (updates.isEmpty) return false;

    if (timestamps) {
      for (var row in updates) {
        _validateFieldsForAssignment(row);
        row.addEntries([MapEntry(updatedAt, DateTime.now())]);
      }
    }

    return super.updateMany(updates, column);
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
  Future<bool> upsert(
    Map<String, dynamic> values,
    List<String> uniqueBy, [
    Map<String, dynamic>? update,
  ]) async {
    _validateFieldsForAssignment(values);

    if (update != null) {
      _validateFieldsForAssignment(update);
    }
    return super.upsert(values, uniqueBy);
  }

  @override
  Future value(String column) async {
    _rejectHidden(column);
    if (softDeletes) {
      whereNull(deletedAt);
    }
    return super.value(column);
  }

  /// Guards the single-column reads against [hidden].
  ///
  /// These name a column outright, so returning null (which is what the
  /// underlying `get` would hand back once the column is stripped) reads
  /// as "no such value" rather than "you may not have this one".
  void _rejectHidden(String column) {
    if (_hiddenColumns.contains(column)) {
      throw InvalidArgumentException(
        'Column $column is hidden on $runtimeType and cannot be read directly.',
      );
    }
  }

  Model include(String relation, [Function(Model qb)? callback]) {
    if (!_relationsRegistered) {
      registerRelations();
      _relationsRegistered = true;
    }

    final rela = _relations[relation];
    if (rela != null && rela is MorphTo) {
      where(rela.morphType, '=', rela.type!);
    }

    _withRelation.add(_RelationQuery(relation, callback));
    return this;
  }

  /// The distinct, non-null values of [key] across [models].
  ///
  /// Rows with a null key have no counterpart to match, and passing null
  /// into `whereIn` would widen the query instead of narrowing it.
  static Set _keysToLoad(List<Map<String, dynamic>> models, String key) {
    final ids = <dynamic>{};
    for (final model in models) {
      final value = model[key];
      if (value != null) ids.add(value);
    }
    return ids;
  }

  Future<void> _eagerLoadRelation(
    List<Map<String, dynamic>> models,
    _RelationQuery rq,
    Function(dynamic data) callBack,
  ) async {
    String relation = rq.relation;
    List<String> wr = relation.split('.');

    String primaryRelation = wr.first;

    List<String> getColumns = ['*'];
    final relationParts = primaryRelation.split(':');

    if (relationParts.length > 1) {
      primaryRelation = relationParts.first.trim();

      final columnsString = relationParts.last.trim();

      if (columnsString.isNotEmpty) {
        getColumns = columnsString
            .split(',')
            .map((col) => col.trim())
            .where((col) => col.isNotEmpty)
            .toList();
      }
    }

    if (!_relations.containsKey(primaryRelation)) {
      throw InvalidArgumentException(
        'Relation $relation not found in $runtimeType',
      );
    }

    Relation rela = _relations[primaryRelation] as Relation;
    Model qb = rela.related;

    // The related model is a single instance held by the relation for the
    // life of the parent, so it still carries the clauses of whichever
    // eager load ran last. Start from a clean builder.
    qb.resetQuery();
    final String relatedTable = qb.getTable;

    if (rq.callback != null) {
      qb = rq.callback!(qb) as Model;
    }

    if (rela is MorphRelation) {
      if (rela is MorphTo) {
        Set ids = _keysToLoad(models, rela.morphKey);

        if (ids.isEmpty) {
          callBack(rela.match(models, [], primaryRelation));
          return;
        }

        qb = qb.whereIn(rela.localKey, ids.toList()) as Model;
      } else {
        Set ids = _keysToLoad(models, rela.localKey);

        if (ids.isEmpty) {
          callBack(rela.match(models, [], primaryRelation));
          return;
        }

        if (rela is MorphToMany || rela is MorphedByMany) {
          // Same shadowing hazard as belongsToMany, except here the query
          // runs FROM the pivot, so the morph columns are the ones that
          // have to survive.
          if (getColumns.length == 1 && getColumns.first == '*') {
            getColumns = [
              '$relatedTable.*',
              '${rela.pivotTable}.${rela.morphKey}',
              '${rela.pivotTable}.${rela.morphType}',
            ];
          }
          qb =
              qb
                      .whereIn(rela.morphKey, ids.toList())
                      .whereEqualTo(rela.morphType, rela.type)
                      .join(
                        rela.related.tableName,
                        '${rela.pivotTable}.${rela.relatedMorphKey}',
                        '=',
                        '${rela.related.tableName}.${rela.localKey}',
                      )
                  as Model;
          qb.tableName = rela.pivotTable!;
        } else {
          qb =
              qb
                      .whereIn(rela.morphKey, ids.toList())
                      .whereEqualTo(rela.morphType, rela.type)
                  as Model;
        }
      }
    } else {
      late final String getLocalKey;
      if (rela is BelongsTo) {
        getLocalKey =
            rela.foreignKey ?? _foreignKeyFor(rela.related.runtimeType);
      } else {
        getLocalKey = rela.localKey;
      }

      Set ids = _keysToLoad(models, getLocalKey);

      if (ids.isEmpty) {
        callBack(rela.match(models, [], primaryRelation));
        return;
      }

      if (rela is BelongsToMany) {
        // `SELECT *` across the join lets pivot columns shadow same-named
        // related ones (`id`, `created_at`). Take the related table whole
        // and name only the pivot column the match needs.
        if (getColumns.length == 1 && getColumns.first == '*') {
          getColumns = [
            '$relatedTable.*',
            '${rela.pivotTable}.${rela.parentPivotKey}',
          ];
        }
        qb =
            qb
                    .whereIn(
                      '${rela.pivotTable}.${rela.parentPivotKey}',
                      ids.toList(),
                    )
                    .join(
                      rela.pivotTable,
                      '${rela.pivotTable}.${rela.relatedPivotKey}',
                      '=',
                      '${rela.related.tableName}.${rela.relatedLocalKey}',
                    )
                as Model;
      } else if (rela is BelongsTo) {
        qb = qb.whereIn(rela.localKey, ids.toList()) as Model;
      } else {
        qb = qb.whereIn(rela.foreignKey!, ids.toList()) as Model;
      }
    }

    final List<Map<String, dynamic>> results;

    try {
      if (wr.length > 1) {
        wr.removeAt(0);
        results = await qb.include(wr.join('.')).get(getColumns);
      } else {
        results = await qb.get(getColumns);
      }
    } finally {
      // The pivot branches above repoint the related model at the pivot
      // table. That instance outlives this load, so put it back.
      qb.tableName = relatedTable;
    }

    callBack(rela.match(models, results, primaryRelation));
  }

  Future<List<Map<String, dynamic>>> _loadRelations(
    List<Map<String, dynamic>> result,
  ) async {
    if (_withRelation.isNotEmpty) {
      final relationsToLoad = List<_RelationQuery>.unmodifiable(_withRelation);
      _withRelation = [];

      for (_RelationQuery relation in relationsToLoad) {
        await _eagerLoadRelation(result, relation, (callBackResult) {
          result = callBackResult;
        });
      }
    }

    return result;
  }

  void _setdefaultConnection(String value) => _connection = value;

  void _validateFieldsForAssignment(Map<String, dynamic> values) {
    List<String> keys = values.keys.toList();
    final List<String> fillable = this.fillable;

    // Timestamps are written by the ORM itself, so they count as fillable
    // without the model having to list them. Built as a local copy: the
    // getter may return a field the model reuses across calls.
    final Set<String> allowed = fillable.isEmpty
        ? const {}
        : {...fillable, createdAt, updatedAt, deletedAt};

    for (String key in keys) {
      if (guarded.contains(key)) {
        throw InvalidArgumentException(
          'Column $key is not allowed to be filled by guarded',
        );
      }

      if (guarded.isEmpty && fillable.isEmpty) {
        throw InvalidArgumentException(
          'Column $key is not allowed to be filled',
        );
      }

      if (allowed.isNotEmpty && !allowed.contains(key)) {
        throw InvalidArgumentException(
          'Column $key is not allowed to be filled',
        );
      }
    }
  }
}

class _RelationQuery {
  final String relation;
  final Function(Model qb)? callback;
  _RelationQuery(this.relation, [this.callback]);
}
