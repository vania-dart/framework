import 'package:vania/src/database/contract/orm/relation.dart';

class HasMany extends Relation {
  HasMany({
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
  ) => matchMany(
    models,
    results,
    relation,
    localKey,
    foreignKey ?? parentForeignKey,
  );
}
