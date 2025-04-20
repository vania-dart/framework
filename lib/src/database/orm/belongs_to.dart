import 'package:vania/src/contract/orm/relation.dart';

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
  ) =>
      matchOneOrMany(
        models,
        results,
        relation,
        localKey,
        foreignKey ?? '${related.runtimeType.toString()}_id',
      );
}
