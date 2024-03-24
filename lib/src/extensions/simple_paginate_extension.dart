import 'package:vania/src/database/simple_pagination.dart';
import 'package:vania/vania.dart';

extension SimplePagination on QueryBuilder {
  Future<Map> simplePagination([int perPage = 15, int page = 1]) async {
    final total = await count();
    final lastPage = (total / perPage).ceil();
    final data = await limit(perPage).offset((page - 1) * perPage).get();

    return SimplePaginationResult(
      next: page < lastPage ? page + 1 : null,
      previous: page > 1 ? page - 1 : null,
      last: lastPage,
      total: total,
      data: data,
    ).response();
  }
}
