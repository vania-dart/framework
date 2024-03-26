class SimplePaginationResult {
  final int? next;
  final int? previous;
  final int last;
  final int first;
  final int total;
  final List<dynamic> data;

  SimplePaginationResult({
    required this.next,
    required this.previous,
    required this.last,
    this.first = 1,
    required this.total,
    required this.data,
  });

  Map response() => {
        'next': next,
        'previous': previous,
        'last': last,
        'first': first,
        'total': total,
        'data': data, // Serialize data objects to JSON
      };
}
