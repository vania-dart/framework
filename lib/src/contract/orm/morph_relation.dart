import 'package:vania/src/contract/orm/relation.dart';

abstract class MorphRelation extends Relation {
  final String morphKey;
  final String morphType;
  final String? type;
  MorphRelation({
    required super.related,
    required super.parent,
    required this.morphKey,
    required this.morphType,
    super.localKey = 'id',
    this.type,
  });
}
