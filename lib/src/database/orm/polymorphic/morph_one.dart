import 'package:vania/src/contract/orm/morph_relation.dart';

class MorphOne extends MorphRelation {
  MorphOne({
    required super.parent,
    required super.related,
    required super.morphKey,
    required super.morphType,
    super.type,
    super.localKey = 'id',
  });

  @override
  List<Map<String, dynamic>> match(
    List<Map<String, dynamic>> models,
    List<Map<String, dynamic>> results,
    String relation,
  ) => matchMorphOneOrMany(
    models,
    results,
    relation,
    localKey,
    morphKey,
    morphType,
    type ?? related.runtimeType.toString().toLowerCase(),
  );
}
