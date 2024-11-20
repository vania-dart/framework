import 'package:vania/src/database/pagination.dart';
import 'package:vania/src/database/simple_pagination.dart';
import 'package:vania/vania_framework.dart';

extension Pagination on QueryBuilder {
  /// Fetches data in a paginated format based on the specified page and number of items per page.
  ///
  /// This method constructs a paginated response including navigation links and total counts, which
  /// makes it easier to implement frontend pagination components.
  ///
  /// **Parameters:**
  /// - [perPage]: Number of items per page. Defaults to 15.
  /// - [page]: Current page number. Defaults to 1.
  /// - [basePath]: Base path for generating pagination links. If not provided, it will be taken from the environment.
  ///
  /// **Returns:**
  /// A `Map` containing paginated results and navigation links.
  ///
  /// **Example Usage:**
  /// Suppose you have a `QueryBuilder` configured for a database table with many entries:
  /// ```dart
  /// var queryBuilder = QueryBuilder();
  /// var paginationResult = await queryBuilder.paginate(10, 2, 'http://example.com/api/items');
  /// print(paginationResult);
  /// ```
  /// **Example Output:**
  /// ```plaintext
  /// {
  ///   'total': 200,
  ///   'perPage': 10,
  ///   'page': 2,
  ///   'lastPage': 20,
  ///   'previousPage': 1,
  ///   'nextPage': 3,
  ///   'nextLink': 'http://example.com/api/items?page=3',
  ///   'previousLink': 'http://example.com/api/items?page=1',
  ///   'lastLink': 'http://example.com/api/items?page=20',
  ///   'firstLink': 'http://example.com/api/items?page=1',
  ///   'data': [...]
  /// }
  /// ```
  Future<Map> paginate(
      [int perPage = 15, int page = 1, String? basePath]) async {
    basePath ?? _getValidBaseUrl(env('APP_URL'));
    final total = await count();
    final lastPage = (total / perPage).ceil();
    final data = await limit(perPage).offset((page - 1) * perPage).get();

    return PaginationResult(
      total: total,
      perPage: perPage,
      page: page,
      lastPage: lastPage,
      previousPage: page > 1 ? page - 1 : null,
      nextPage: page < lastPage ? page + 1 : null,
      nextLink: page < lastPage ? '$basePath?page=${page + 1}' : '',
      previousLink: page > 1 ? '$basePath?page=${page - 1}' : '',
      lastLink: '$basePath?page=$lastPage',
      firstLink: '$basePath?page=1',
      data: data,
    ).response();
  }

  String? _getValidBaseUrl(String? url) {
    if (url == null || url.isEmpty) {
      throw ArgumentError('Base URL must be provided and cannot be empty.');
    }
    // Further validation can be added here (e.g., URL format validation)
    return url;
  }

  /// Fetches data in a simple paginated format without advanced configuration.
  /// This method is deprecated and will be removed in future releases. Use [simplePaginate] instead.
  ///
  /// **Parameters:**
  /// - [perPage]: Number of items per page, defaults to 15.
  /// - [page]: Current page number, defaults to 1.
  ///
  /// **Returns:**
  /// A `Map` containing simplified paginated results.
  ///
  /// **Example Usage:**
  /// Suppose you have a `QueryBuilder` configured for a database table:
  /// ```dart
  /// var queryBuilder = QueryBuilder();
  /// var simplePaginationResult = await queryBuilder.simplePagination(10, 1);
  /// print(simplePaginationResult);
  /// ```
  /// **Example Output:**
  /// ```plaintext
  /// {
  ///   'next': 2,
  ///   'previous': null,
  ///   'last': 10,
  ///   'total': 95,
  ///   'data': [...]
  /// }
  /// ```
  @Deprecated(
      'Use simplePaginate instead. This method will be removed in future releases.')
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

  /// Fetches data in a simple paginated format based on specified parameters.
  ///
  /// **Parameters:**
  /// - [perPage]: Number of items per page, defaults to 15.
  /// - [page]: Current page number, defaults to 1.
  ///
  /// **Returns:**
  /// A `Map` containing simplified paginated results.
  ///
  /// **Example Usage:**
  /// Example demonstrating calling `simplePaginate`:
  /// ```dart
  /// var queryBuilder = QueryBuilder();
  /// var paginationResult = await queryBuilder.simplePaginate(10, 2);
  /// print(paginationResult);
  /// ```
  /// **Example Output:**
  /// ```plaintext
  /// {
  ///   'next': 3,
  ///   'previous': 1,
  ///   'last': 20,
  ///   'total': 195,
  ///   'data': [...]
  /// }
  /// ```
  Future<Map> simplePaginate([int perPage = 15, int page = 1]) async {
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
