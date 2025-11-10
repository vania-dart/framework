import 'dart:convert';

import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class GreaterThan extends ValidationRule {
  final num compare;
  GreaterThan({required this.compare, super.message});
  @override
  bool validate(value, data) {
    value = num.parse(value.toString());
    return value > num.parse(compare.toString());
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The $field be greater than $compare';
  }

  GreaterThan copyWith({num? compare}) {
    return GreaterThan(compare: compare ?? this.compare);
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    result.addAll({'compare': compare});

    return result;
  }

  factory GreaterThan.fromMap(Map<String, dynamic> map) {
    return GreaterThan(compare: map['compare'] ?? 0);
  }

  String toJson() => json.encode(toMap());

  factory GreaterThan.fromJson(String source) =>
      GreaterThan.fromMap(json.decode(source));

  @override
  String toString() => 'GreaterThan(compare: $compare)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is GreaterThan && other.compare == compare;
  }

  @override
  int get hashCode => compare.hashCode;
}
