class PaginationResult {
  final int total;
  final int perPage;
  final int page;
  final int lastPage;
  final int? previousPage;
  final int? nextPage;
  final String nextLink;
  final String previousLink;
  final String lastLink;
  final String firstLink;
  final List<dynamic> data;

  PaginationResult({
    required this.total,
    required this.perPage,
    required this.page,
    required this.lastPage,
    required this.previousPage,
    required this.nextPage,
    required this.nextLink,
    required this.previousLink,
    required this.lastLink,
    required this.firstLink,
    required this.data,
  });

  Map response() => {
        'total': total,
        'perPage': perPage,
        'page': page,
        'lastPage': lastPage,
        'previousPage': previousPage,
        'nextPage': nextPage,
        'nextLink': nextLink,
        'previousLink': previousLink,
        'lastLink': lastLink,
        'firstLink': firstLink,
        'data': data,
      };
}
