import 'package:vania/src/contract/orm/relation.dart';

abstract class MorphRelation extends Relation {
  final String morphKey;
  final String morphType;
  final String? type;
  final String? pivotTable;
  final String? relatedMorphKey;
  MorphRelation({
    required super.related,
    required super.parent,
    required this.morphKey,
    required this.morphType,
    this.pivotTable,
    this.relatedMorphKey,
    super.localKey = 'id',
    this.type,
  });
}
