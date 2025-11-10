import 'package:meta/meta.dart';

import '../../contract/database/query_builder/query_builder.dart';
import '../../exception/invalid_argument_exception.dart';
import '_cte/_cte_cache.dart';
import '_cte/_cte_configuration.dart';
import '_cte/_cte_definition.dart';
import '_cte/_cte_feature.dart';
import '_cte/_duplicate_cte_name_exception.dart';
import '_cte/_invalid_cte_configuration_exception.dart';
import '_cte/_sql_identifier_escaper.dart';
import '_cte/_standard_escaping_strategy.dart';
import '_cte/_unsupported_cte_feature_exception.dart';

mixin QueryBuilderAccessor on QueryBuilder {
  Map<String, dynamic> accessBindings() => getBindings();
}

abstract mixin class CteBuilderImpl implements QueryBuilder {
  @protected
  final List<CteDefinition> _ctes = [];

  final Set<String> _cteNames = <String>{};

  CteConfiguration _config = const CteConfiguration();
  final CteCache _cache = CteCache();
  late final IdentifierEscapingStrategy _escapingStrategy;

  void configureCte(CteConfiguration config) {
    if (_config != config) {
      _config = config;
      _cache.markDirty();
      _escapingStrategy = StandardEscapingStrategy(config.quoteChar);
    }
  }

  CteConfiguration get cteConfiguration => _config;

  @override
  QueryBuilder withCte(
    String name,
    QueryBuilder subQuery, {
    List<String>? columns,
  }) {
    _validateAndAddCte(name, subQuery, columns: columns);
    return this;
  }

  @override
  QueryBuilder withMultiple(
    Map<String, QueryBuilder> ctes, {
    Map<String, List<String>>? columnsMap,
  }) {
    if (ctes.isEmpty) {
      throw InvalidArgumentException('CTEs map cannot be empty');
    }

    for (String name in ctes.keys) {
      SqlIdentifierEscaper.validateIdentifier(name, context: 'CTE name');
      if (_cteNames.contains(name.toLowerCase())) {
        throw DuplicateCteNameException(name);
      }
    }

    for (var entry in ctes.entries) {
      List<String>? columns = columnsMap?[entry.key];
      _addCteDefinition(entry.key, entry.value, columns: columns);
    }

    return this;
  }

  @override
  QueryBuilder withRecursive(
    String name,
    QueryBuilder baseCase,
    QueryBuilder recursiveCase, {
    List<String>? columns,
  }) {
    if (!_config.supportsFeature(CteFeature.recursive)) {
      throw UnsupportedCteFeatureException(
        CteFeature.recursive,
        _config.databaseType,
        name,
      );
    }

    _validateAndAddCte(
      name,
      baseCase,
      isRecursive: true,
      recursiveQuery: recursiveCase,
      columns: columns,
    );
    return this;
  }

  @override
  QueryBuilder withMaterialized(
    String name,
    QueryBuilder subQuery, {
    List<String>? columns,
  }) {
    if (!_config.supportsFeature(CteFeature.materialized)) {
      throw UnsupportedCteFeatureException(
        CteFeature.materialized,
        _config.databaseType,
        name,
      );
    }

    _validateAndAddCte(name, subQuery, isMaterialized: true, columns: columns);
    return this;
  }

  @override
  QueryBuilder withNotMaterialized(
    String name,
    QueryBuilder subQuery, {
    List<String>? columns,
  }) {
    if (!_config.supportsFeature(CteFeature.notMaterialized)) {
      throw UnsupportedCteFeatureException(
        CteFeature.notMaterialized,
        _config.databaseType,
        name,
      );
    }

    _validateAndAddCte(
      name,
      subQuery,
      isNotMaterialized: true,
      columns: columns,
    );
    return this;
  }

  void _validateAndAddCte(
    String name,
    QueryBuilder query, {
    bool isRecursive = false,
    bool isMaterialized = false,
    bool isNotMaterialized = false,
    QueryBuilder? recursiveQuery,
    List<String>? columns,
  }) {
    SqlIdentifierEscaper.validateIdentifier(name, context: 'CTE name');

    String lowerName = name.toLowerCase();
    if (_cteNames.contains(lowerName)) {
      throw DuplicateCteNameException(name);
    }

    _addCteDefinition(
      name,
      query,
      isRecursive: isRecursive,
      isMaterialized: isMaterialized,
      isNotMaterialized: isNotMaterialized,
      recursiveQuery: recursiveQuery,
      columns: columns,
    );
  }

  void _addCteDefinition(
    String name,
    QueryBuilder query, {
    bool isRecursive = false,
    bool isMaterialized = false,
    bool isNotMaterialized = false,
    QueryBuilder? recursiveQuery,
    List<String>? columns,
  }) {
    final cte = CteDefinition(
      name: name,
      query: query,
      isRecursive: isRecursive,
      isMaterialized: isMaterialized,
      isNotMaterialized: isNotMaterialized,
      recursiveQuery: recursiveQuery,
      columns: columns,
    );

    cte.validate(_config);

    _ctes.add(cte);
    _cteNames.add(name.toLowerCase());
    _cache.markDirty();
  }

  @protected
  void validateAllCtes() {
    for (var cte in _ctes) {
      cte.validate(_config);
    }

    int recursiveCount = _ctes.where((cte) => cte.isRecursive).length;
    if (recursiveCount > _config.maxCteDepth) {
      throw InvalidCteConfigurationException(
        'Too many recursive CTEs: $recursiveCount (max: ${_config.maxCteDepth})',
      );
    }
  }

  @protected
  String buildWithClause() {
    if (_ctes.isEmpty) return '';

    int currentHashCode = _calculateCteHashCode();

    if (_config.enableCaching && !_cache.needsUpdate(currentHashCode)) {
      return _cache.cachedWithClause ?? '';
    }

    validateAllCtes();

    List<String> cteStrings = [];
    bool hasRecursive = _ctes.any((cte) => cte.isRecursive);

    _escapingStrategy = StandardEscapingStrategy(_config.quoteChar);

    for (var cte in _ctes) {
      cteStrings.add(cte.toSql(_escapingStrategy, _config));
    }

    String withClause = hasRecursive ? 'WITH RECURSIVE ' : 'WITH ';
    withClause += cteStrings.join(', ');

    if (_config.enableCaching) {
      Map<String, dynamic> bindings = _calculateCteBindings();
      _cache.updateCache(withClause, bindings, currentHashCode);
    }

    return withClause;
  }

  @protected
  Map<String, dynamic> getCteBindings() {
    if (_ctes.isEmpty) return {};

    int currentHashCode = _calculateCteHashCode();

    if (_config.enableCaching && !_cache.needsUpdate(currentHashCode)) {
      return _cache.cachedBindings ?? {};
    }

    return _calculateCteBindings();
  }

  Map<String, dynamic> _calculateCteBindings() {
    Map<String, dynamic> allBindings = {};

    for (int i = 0; i < _ctes.length; i++) {
      var cte = _ctes[i];
      Map<String, dynamic> cteBindings = cte.getBindings();

      for (var entry in cteBindings.entries) {
        String key = entry.key;
        if (allBindings.containsKey(key)) {
          int counter = 1;
          String newKey;
          do {
            newKey = '${key}_cte${i}_$counter';
            counter++;
          } while (allBindings.containsKey(newKey));
          allBindings[newKey] = entry.value;
        } else {
          allBindings[key] = entry.value;
        }
      }
    }

    return allBindings;
  }

  int _calculateCteHashCode() {
    return Object.hash(
      _ctes.map((cte) => cte.hashCode).toList(),
      _config.hashCode,
    );
  }

  @protected
  void clearCtes() {
    _ctes.clear();
    _cteNames.clear();
    _cache.clear();
  }

  @protected
  bool get hasCtes => _ctes.isNotEmpty;

  @protected
  List<String> get cteNames => _cteNames.toList();

  @protected
  int get cteCount => _ctes.length;

  @protected
  bool hasCte(String name) => _cteNames.contains(name.toLowerCase());

  @protected
  bool removeCte(String name) {
    String lowerName = name.toLowerCase();
    final index = _ctes.indexWhere(
      (cte) => cte.name.toLowerCase() == lowerName,
    );
    if (index != -1) {
      _ctes.removeAt(index);
      _cteNames.remove(lowerName);
      _cache.markDirty();
      return true;
    }
    return false;
  }

  @protected
  List<Map<String, dynamic>> getCteInfo() {
    return _ctes
        .map(
          (cte) => {
            'name': cte.name,
            'isRecursive': cte.isRecursive,
            'isMaterialized': cte.isMaterialized,
            'isNotMaterialized': cte.isNotMaterialized,
            'hasColumns': cte.columns != null && cte.columns!.isNotEmpty,
            'columnCount': cte.columns?.length ?? 0,
            'columns': cte.columns,
            'hashCode': cte.hashCode,
          },
        )
        .toList();
  }

  @protected
  Map<String, dynamic> getCacheStats() {
    return {
      'isCacheEnabled': _config.enableCaching,
      'isCacheValid': !_cache.needsUpdate(_calculateCteHashCode()),
      'hasCachedWithClause': _cache.cachedWithClause != null,
      'hasCachedBindings': _cache.cachedBindings != null,
      'currentHashCode': _calculateCteHashCode(),
    };
  }
}
