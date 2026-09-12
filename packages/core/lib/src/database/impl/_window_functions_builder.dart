part of 'legacy_query_builder.dart';

abstract interface class WindowFunctionsBuilder {
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
}
