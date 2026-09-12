import 'package:vania/src/database/contract/orm/relation.dart';

class HasOne extends Relation {
  HasOne({
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
  ) => matchOneOrMany(
    models,
    results,
    relation,
    localKey,
    foreignKey ?? parentForeignKey,
  );
}
