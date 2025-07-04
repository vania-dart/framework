import 'package:meta/meta.dart';

import '../../contract/database/query_builder/query_builder.dart'
    show QueryBuilder;
import '../../exception/invalid_argument_exception.dart';

abstract mixin class WindowFunctionsBuilderImpl implements QueryBuilder {
  @protected
  final List<String> _windowFunctions = [];

  String _buildOverClause({String? partitionBy, String? orderBy}) {
    List<String> overParts = [];

    if (partitionBy != null && partitionBy.isNotEmpty) {
      overParts.add("PARTITION BY $partitionBy");
    }

    if (orderBy != null && orderBy.isNotEmpty) {
      overParts.add("ORDER BY $orderBy");
    }

    return "OVER (${overParts.join(' ')})";
  }

  void _addWindowFunction(
      String functionName, String overClause, String? alias) {
    String windowFunc = "$functionName $overClause";
    if (alias != null && alias.isNotEmpty) {
      windowFunc += " AS $alias";
    }

    selectColumns.add(windowFunc);
    _windowFunctions.add(windowFunc);
  }

  @override
  QueryBuilder rowNumber({
    String? partitionBy,
    String? orderBy,
    String? as,
  }) {
    final overClause =
        _buildOverClause(partitionBy: partitionBy, orderBy: orderBy);
    _addWindowFunction("ROW_NUMBER()", overClause, as);
    return this;
  }

  @override
  QueryBuilder rank({
    String? partitionBy,
    String? orderBy,
    String? as,
  }) {
    final overClause =
        _buildOverClause(partitionBy: partitionBy, orderBy: orderBy);
    _addWindowFunction("RANK()", overClause, as);
    return this;
  }

  @override
  QueryBuilder denseRank({
    String? partitionBy,
    String? orderBy,
    String? as,
  }) {
    final overClause =
        _buildOverClause(partitionBy: partitionBy, orderBy: orderBy);
    _addWindowFunction("DENSE_RANK()", overClause, as);
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
    if (column.isEmpty) {
      throw InvalidArgumentException(
          'Column name cannot be empty for LAG function');
    }

    String lagFunc = "LAG($column, $offset";
    if (defaultValue != null) {
      if (defaultValue is String) {
        lagFunc += ", '$defaultValue'";
      } else {
        lagFunc += ", $defaultValue";
      }
    }
    lagFunc += ")";

    final overClause =
        _buildOverClause(partitionBy: partitionBy, orderBy: orderBy);
    _addWindowFunction(lagFunc, overClause, as);
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
    if (column.isEmpty) {
      throw InvalidArgumentException(
          'Column name cannot be empty for LEAD function');
    }

    String leadFunc = "LEAD($column, $offset";
    if (defaultValue != null) {
      if (defaultValue is String) {
        leadFunc += ", '$defaultValue'";
      } else {
        leadFunc += ", $defaultValue";
      }
    }
    leadFunc += ")";

    final overClause =
        _buildOverClause(partitionBy: partitionBy, orderBy: orderBy);
    _addWindowFunction(leadFunc, overClause, as);
    return this;
  }

  @override
  QueryBuilder firstValue(
    String column, {
    String? partitionBy,
    String? orderBy,
    String? as,
  }) {
    if (column.isEmpty) {
      throw InvalidArgumentException(
          'Column name cannot be empty for FIRST_VALUE function');
    }

    final overClause =
        _buildOverClause(partitionBy: partitionBy, orderBy: orderBy);
    _addWindowFunction("FIRST_VALUE($column)", overClause, as);
    return this;
  }

  @override
  QueryBuilder lastValue(
    String column, {
    String? partitionBy,
    String? orderBy,
    String? as,
  }) {
    if (column.isEmpty) {
      throw InvalidArgumentException(
          'Column name cannot be empty for LAST_VALUE function');
    }

    final overClause =
        _buildOverClause(partitionBy: partitionBy, orderBy: orderBy);
    _addWindowFunction("LAST_VALUE($column)", overClause, as);
    return this;
  }

  @override
  QueryBuilder ntile(
    int buckets, {
    String? partitionBy,
    String? orderBy,
    String? as,
  }) {
    if (buckets <= 0) {
      throw InvalidArgumentException(
          'Number of buckets must be greater than 0');
    }

    final overClause =
        _buildOverClause(partitionBy: partitionBy, orderBy: orderBy);
    _addWindowFunction("NTILE($buckets)", overClause, as);
    return this;
  }

  @override
  QueryBuilder percentRank({
    String? partitionBy,
    String? orderBy,
    String? as,
  }) {
    final overClause =
        _buildOverClause(partitionBy: partitionBy, orderBy: orderBy);
    _addWindowFunction("PERCENT_RANK()", overClause, as);
    return this;
  }

  @override
  QueryBuilder cumeDist({
    String? partitionBy,
    String? orderBy,
    String? as,
  }) {
    final overClause =
        _buildOverClause(partitionBy: partitionBy, orderBy: orderBy);
    _addWindowFunction("CUME_DIST()", overClause, as);
    return this;
  }

  @override
  QueryBuilder windowSum(
    String column, {
    String? partitionBy,
    String? orderBy,
    String? as,
  }) {
    if (column.isEmpty) {
      throw InvalidArgumentException(
          'Column name cannot be empty for SUM window function');
    }

    final overClause =
        _buildOverClause(partitionBy: partitionBy, orderBy: orderBy);
    _addWindowFunction("SUM($column)", overClause, as);
    return this;
  }

  @override
  QueryBuilder windowAvg(
    String column, {
    String? partitionBy,
    String? orderBy,
    String? as,
  }) {
    if (column.isEmpty) {
      throw InvalidArgumentException(
          'Column name cannot be empty for AVG window function');
    }

    final overClause =
        _buildOverClause(partitionBy: partitionBy, orderBy: orderBy);
    _addWindowFunction("AVG($column)", overClause, as);
    return this;
  }

  @override
  QueryBuilder windowCount(
    String column, {
    String? partitionBy,
    String? orderBy,
    String? as,
  }) {
    if (column.isEmpty) {
      throw InvalidArgumentException(
          'Column name cannot be empty for COUNT window function');
    }

    final overClause =
        _buildOverClause(partitionBy: partitionBy, orderBy: orderBy);
    _addWindowFunction("COUNT($column)", overClause, as);
    return this;
  }

  @override
  QueryBuilder windowMax(
    String column, {
    String? partitionBy,
    String? orderBy,
    String? as,
  }) {
    if (column.isEmpty) {
      throw InvalidArgumentException(
          'Column name cannot be empty for MAX window function');
    }

    final overClause =
        _buildOverClause(partitionBy: partitionBy, orderBy: orderBy);
    _addWindowFunction("MAX($column)", overClause, as);
    return this;
  }

  @override
  QueryBuilder windowMin(
    String column, {
    String? partitionBy,
    String? orderBy,
    String? as,
  }) {
    if (column.isEmpty) {
      throw InvalidArgumentException(
          'Column name cannot be empty for MIN window function');
    }

    final overClause =
        _buildOverClause(partitionBy: partitionBy, orderBy: orderBy);
    _addWindowFunction("MIN($column)", overClause, as);
    return this;
  }

  @protected
  void clearWindowFunctions() {
    _windowFunctions.clear();
  }
}
