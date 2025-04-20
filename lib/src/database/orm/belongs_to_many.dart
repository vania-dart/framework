import 'package:vania/src/contract/orm/relation.dart';

class BelongsToMany extends Relation {
  BelongsToMany({
    required super.related,
    required super.parent,
    super.foreignKey,
    required super.localKey,
  });

  @override
  List<Map<String, dynamic>> match(
    List<Map<String, dynamic>> models,
    List<Map<String, dynamic>> results,
    String relation,
  ) =>
      matchMany(
        models,
        results,
        relation,
        localKey,
        foreignKey ?? '${related.runtimeType.toString().toLowerCase()}_id',
      );
}
