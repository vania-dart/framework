part of 'query_builder.dart';

abstract class QueryExecutorBuilder {
  Future<num> avg(String column);
  Future<void> chunk(
    int count,
    void Function(List<Map<String, dynamic>> chunk) callback,
  );
  Future<void> chunkById(
    int count,
    void Function(List<Map<String, dynamic>> chunk) callback, [
    String column,
  ]);
  Future<int> count([String columns = '*']);
  Future<bool> doesntExist();
  Future<void> each(
    void Function(Map<String, dynamic>) callback,
  );
  Future<bool> exists();
  Future<Map<String, dynamic>?> find(
    dynamic id, [
    List<String> columns = const ['*'],
  ]);

  Future<Map<String, dynamic>?> findOrFail(
    dynamic id, [
    List<String> columns = const ['*'],
  ]);
  Future<Map<String, dynamic>?> first([
    List<String> columns,
  ]);
  Future<Map<String, dynamic>?> firstOrFail([
    List<String> columns = const ['*'],
  ]);
  Future<Map<String, dynamic>?> firstWhere(
    String column, [
    String? operator,
    dynamic value,
    List<String> columns = const ['*'],
  ]);
  Future<List<Map<String, dynamic>>> get([
    List<String> columns,
  ]);

  Stream<Iterable<Map<String, dynamic>>> lazy([
    int chunk = 1000,
  ]);
  Future<dynamic> max(String column);
  Future<dynamic> min(String column);
  Future<Map<String, dynamic>> paginate({
    int perPage = 15,
    List<String> columns = const ['*'],
    String? pageName,
    int? page,
  });
  Future<dynamic> pluck(
    String column, [
    String? key,
  ]);
  Future<Map<String, dynamic>> simplePaginate([
    int perPage,
    List<String> columns,
    String pageName,
    int? page,
  ]);
  Future<num> sum(String column);

  Future<dynamic> value(String column);
}
