class ValidationItem {
  final String field;
  final String name;
  final String rule;
  final dynamic value;

  const ValidationItem({
    required this.field,
    required this.name,
    required this.rule,
    this.value,
  });
}
