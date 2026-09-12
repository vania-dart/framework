import 'package:vania/src/database/contract/orm/morph_relation.dart';

class MorphToMany extends MorphRelation {
  MorphToMany({
    required super.parent,
    required super.related,
    required super.morphKey,
    required super.morphType,
    required super.pivotTable,
    required super.relatedMorphKey,
    super.type,
    super.localKey = 'id',
  });

  @override
  List<Map<String, dynamic>> match(
    List<Map<String, dynamic>> models,
    List<Map<String, dynamic>> results,
    String relation,
  ) {
    return matchMorphMany(
      models,
      results,
      relation,
      localKey,
      morphKey,
      morphType,
      type ?? related.runtimeType.toString().toLowerCase(),
    );
  }
}
