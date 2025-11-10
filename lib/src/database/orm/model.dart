import 'package:meta/meta.dart';
import 'package:vania/query_builder.dart';
import 'package:vania/src/contract/database/query_builder/query_builder.dart';
import 'package:vania/src/contract/orm/morph_relation.dart';
import 'package:vania/src/contract/orm/relation.dart';
import 'package:vania/src/database/_database_utils/_singularize.dart';
import 'package:vania/src/database/orm/polymorphic/morphed_by_many.dart';
import 'package:vania/src/database/query_builder/_query_builder_impl.dart';
import 'package:vania/src/exception/invalid_argument_exception.dart';
import 'package:vania/src/utils/_pluralize.dart';
import 'package:vania/src/utils/functions.dart';

import '../../utils/request_helper.dart' show getParam;
import 'belongs_to.dart';
import 'belongs_to_many.dart';
import 'has_many.dart';
import 'has_one.dart';
import 'polymorphic/morph_many.dart';
import 'polymorphic/morph_one.dart';
import 'polymorphic/morph_to.dart';
import 'polymorphic/morph_to_many.dart';

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
  @protected
  List<String> get hidden => [];
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

  @protected
  String get tableName =>
      toSnakeCase(Pluralize().make(runtimeType.toString())).toLowerCase();

  set tableName(String table) {
    _table = table;
  }

  @protected
  bool get timestamps => true;

  bool _relationsRegistered = false;

  /// Override this method to define model relationships
  /// This method is called automatically when include() is used
  void registerRelations() {}

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
          foreignKey:
              foreignKey ?? '${model.runtimeType.toString()}_id'.toLowerCase(),
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
              '${Singularize.make(model.runtimeType.toString())}_${Singularize.make(runtimeType.toString())}'
                  .toLowerCase(),
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
      for (Map<String, dynamic> map in data) {
        map.removeWhere((key, _) => hidden.contains(key));
      }
      final result = await _loadRelations(data);
      callback(result);
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
      for (Map<String, dynamic> map in data) {
        map.removeWhere((key, _) => hidden.contains(key));
      }
      final result = await _loadRelations(data);
      callback(result);
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
    try {
      if (softDeletes) {
        final now = DateTime.now();
        super.update({deletedAt: now, updatedAt: now});
      } else {
        super.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
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

    if (result != null) {
      List<Map<String, dynamic>> data = [result];
      result = (await _loadRelations(data)).first;
    }

    return result;
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
    return (await _loadRelations([result])).first;
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

      for (Map<String, dynamic> map in result) {
        map.removeWhere((key, _) => hidden.contains(key));
      }

      return _loadRelations(result);
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
          foreignKey:
              foreignKey ?? '${runtimeType.toString()}_id'.toLowerCase(),
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
          foreignKey:
              foreignKey ?? '${runtimeType.toString()}_id'.toLowerCase(),
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

  Model newInstance() {
    return (runtimeType as dynamic)();
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
    if (softDeletes) {
      whereNull(deletedAt);
    }
    return super.pluck(column);
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
    for (var key in hidden) {
      result.remove(key);
    }
    _relations.forEach((key, relation) {
      if (relation is! Future<dynamic>) {
        result[key] = relation;
      }
    });
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
    if (softDeletes) {
      whereNull(deletedAt);
    }
    return super.value(column);
  }

  Model include(String relation, [Function(Model qb)? callback]) {
    if (!_relationsRegistered) {
      registerRelations();
      _relationsRegistered = true;
      final rela = _relations[relation];
      if (rela != null && rela is MorphTo) {
        where(rela.morphType, '=', rela.type!);
      }
    }

    _withRelation.add(_RelationQuery(relation, callback));
    return this;
  }

  void _clearWithRelation(_RelationQuery r) {
    if (_withRelation.length == 1) {
      _withRelation = [];
    } else {
      _withRelation.remove(r);
    }
  }

  Future<void> _eagerLoadRelation(
    List<Map<String, dynamic>> models,
    _RelationQuery rq,
    Function(dynamic data) callBack,
  ) async {
    String relation = rq.relation;

    if (_withRelation.any((r) => r.relation == relation)) {
      List<String> wr = relation.split('.');

      String primaryRelation = wr.first;

      if (!_relations.containsKey(primaryRelation)) {
        throw InvalidArgumentException(
          'Relation $relation not found in $runtimeType',
        );
      }

      Relation rela = _relations[primaryRelation] as Relation;
      Model qb = rela.related;
      rela.parent._clearWithRelation(rq);

      if (rq.callback != null) {
        qb = rq.callback!(qb) as Model;
      }

      if (rela is MorphRelation) {
        if (rela is MorphTo) {
          Set ids = models.map((m) => m[rela.morphKey]).toSet();
          qb = qb.whereIn(rela.localKey, ids.toList()) as Model;
        } else {
          Set ids = models.map((m) => m[rela.localKey]).toSet();

          if (rela is MorphToMany || rela is MorphedByMany) {
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
        Set ids = models.map((m) => m[rela.localKey]).toSet();

        if (rela is BelongsToMany) {
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
      if (wr.length > 1) {
        wr.removeAt(0);
        var results = await qb.include(wr.join('.')).get();
        callBack(rela.match(models, results, primaryRelation));
      } else {
        var results = await qb.get();

        callBack(rela.match(models, results, primaryRelation));
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadRelations(
    List<Map<String, dynamic>> result,
  ) async {
    if (_withRelation.isNotEmpty) {
      for (_RelationQuery relation in _withRelation) {
        await _eagerLoadRelation(result, relation, (callBackResult) {
          result = callBackResult;
        });
      }
    }

    return result;
  }

  void _setdefaultConnection(String value) => _connection = value;

  /// Validates field names for mass assignment according to fillable and guarded rules
  /// Throws [InvalidArgumentException] if validation fails
  void _validateFieldsForAssignment(Map<String, dynamic> values) {
    List<String> keys = values.keys.toList();

    if (fillable.isNotEmpty) {
      fillable.add(createdAt);
      fillable.add(updatedAt);
      fillable.add(deletedAt);
    }

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

      if (!guarded.contains(key) &&
          fillable.isNotEmpty &&
          !fillable.contains(key)) {
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
