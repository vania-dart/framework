part of '../../contract/database/query_builder/query_builder.dart';

class PaginatedResult {
  final List<Map<String, dynamic>> data;
  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;
  final bool isFirst;
  final bool isLast;
  final bool hasMore;

  PaginatedResult({
    required this.data,
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
    required this.isFirst,
    required this.isLast,
    required this.hasMore,
  });

  Map<String, dynamic> toMap() => {
    'data': data,
    'current_page': currentPage,
    'per_page': perPage,
    'total': total,
    'last_page': lastPage,
    'is_first': isFirst,
    'is_last': isLast,
    'has_more': hasMore,
  };

  @override
  String toString() {
    return 'PaginatedResult(currentPage: $currentPage, perPage: $perPage, total: $total, lastPage: $lastPage, data: $data)';
  }
}
