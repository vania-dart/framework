import 'package:vania/src/contract/database/query_builder/query_builder.dart';

import '../_cte_builder_impl.dart';
import '_cte_configuration.dart';
import '_cte_feature.dart';
import '_invalid_cte_configuration_exception.dart';
import '_sql_identifier_escaper.dart';
import '_standard_escaping_strategy.dart';
import '_unsupported_cte_feature_exception.dart';

class CteDefinition {
  final String name;

  final QueryBuilder query;

  final bool isRecursive;

  final bool isMaterialized;

  final bool isNotMaterialized;

  final QueryBuilder? recursiveQuery;

  final List<String>? columns;

  const CteDefinition({
    required this.name,
    required this.query,
    this.isRecursive = false,
    this.isMaterialized = false,
    this.isNotMaterialized = false,
    this.recursiveQuery,
    this.columns,
  });

  void validate(CteConfiguration config) {
    SqlIdentifierEscaper.validateIdentifier(name, context: 'CTE name');

    if (isRecursive && !config.supportsFeature(CteFeature.recursive)) {
      throw UnsupportedCteFeatureException(
          CteFeature.recursive, config.databaseType, name);
    }

    if (isMaterialized && !config.supportsFeature(CteFeature.materialized)) {
      throw UnsupportedCteFeatureException(
          CteFeature.materialized, config.databaseType, name);
    }

    if (isNotMaterialized &&
        !config.supportsFeature(CteFeature.notMaterialized)) {
      throw UnsupportedCteFeatureException(
          CteFeature.notMaterialized, config.databaseType, name);
    }

    if (isRecursive && recursiveQuery == null) {
      throw InvalidCteConfigurationException(
          'Recursive CTE must have recursive query', name);
    }

    if (isMaterialized && isNotMaterialized) {
      throw InvalidCteConfigurationException(
          'CTE cannot be both materialized and not materialized', name);
    }

    if (isRecursive && (isMaterialized || isNotMaterialized)) {
      throw InvalidCteConfigurationException(
          'Recursive CTE cannot have materialization options', name);
    }

    if (columns != null && columns!.isNotEmpty) {
      for (String column in columns!) {
        SqlIdentifierEscaper.validateIdentifier(column, context: 'Column name');
      }

      Set<String> uniqueColumns = columns!.map((c) => c.toLowerCase()).toSet();
      if (uniqueColumns.length != columns!.length) {
        throw InvalidCteConfigurationException(
            'CTE columns must be unique', name);
      }
    }
  }

  String toSql(
      IdentifierEscapingStrategy escapingStrategy, CteConfiguration config) {
    validate(config);

    String escapedName = escapingStrategy.escape(name);
    String sql = escapedName;

    if (columns != null && columns!.isNotEmpty) {
      List<String> escapedColumns =
          columns!.map((col) => escapingStrategy.escape(col)).toList();
      sql += ' (${escapedColumns.join(', ')})';
    }

    if (isRecursive && recursiveQuery != null) {
      sql += ' AS (${query.toSql()} UNION ALL ${recursiveQuery!.toSql()})';
    } else if (isMaterialized &&
        config.supportsFeature(CteFeature.materialized)) {
      sql += ' AS MATERIALIZED (${query.toSql()})';
    } else if (isNotMaterialized &&
        config.supportsFeature(CteFeature.notMaterialized)) {
      sql += ' AS NOT MATERIALIZED (${query.toSql()})';
    } else {
      sql += ' AS (${query.toSql()})';
    }

    return sql;
  }

  Map<String, dynamic> getBindings() {
    Map<String, dynamic> allBindings = {};

    if (query is QueryBuilderAccessor) {
      Map<String, dynamic> queryBindings =
          (query as QueryBuilderAccessor).accessBindings();
      allBindings.addAll(queryBindings);
    }

    if (recursiveQuery != null && recursiveQuery is QueryBuilderAccessor) {
      Map<String, dynamic> recursiveBindings =
          (recursiveQuery as QueryBuilderAccessor).accessBindings();

      for (var entry in recursiveBindings.entries) {
        String key = entry.key;
        if (allBindings.containsKey(key)) {
          int counter = 1;
          String newKey;
          do {
            newKey = '${key}_rec_$counter';
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

  @override
  int get hashCode {
    return Object.hash(
      name,
      query.hashCode,
      isRecursive,
      isMaterialized,
      isNotMaterialized,
      recursiveQuery?.hashCode,
      columns?.join(','),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CteDefinition &&
        other.name == name &&
        other.query == query &&
        other.isRecursive == isRecursive &&
        other.isMaterialized == isMaterialized &&
        other.isNotMaterialized == isNotMaterialized &&
        other.recursiveQuery == recursiveQuery &&
        _listEquals(other.columns, columns);
  }

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'CTE($name, recursive: $isRecursive, materialized: $isMaterialized)';
  }
}
