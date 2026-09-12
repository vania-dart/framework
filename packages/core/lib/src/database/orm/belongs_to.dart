import 'package:vania/src/database/contract/orm/relation.dart';

class BelongsTo extends Relation {
  BelongsTo({
    required super.related,
    required super.parent,
    super.foreignKey,
    super.localKey,
  });

  @override
  List<Map<String, dynamic>> match(
    List<Map<String, dynamic>> models,
    List<Map<String, dynamic>> results,
    String relation,
  ) => matchOneOrMany(
    models,
    results,
    relation,
    foreignKey ?? '${related.runtimeType.toString()}_id',
    localKey,
  );
}
