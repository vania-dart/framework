import 'package:vania/src/database/contract/orm/relation.dart';

class BelongsToMany extends Relation {
  final String pivotTable;
  final String parentPivotKey;
  final String relatedPivotKey;
  final String parentLocalKey;
  final String relatedLocalKey;
  final List<String> pivotFields;

  BelongsToMany({
    required super.parent,
    required super.related,
    required this.pivotTable,
    required this.parentPivotKey,
    required this.relatedPivotKey,
    this.parentLocalKey = 'id',
    this.relatedLocalKey = 'id',
    this.pivotFields = const [],
  });

  @override
  List<Map<String, dynamic>> match(
    List<Map<String, dynamic>> parents,
    List<Map<String, dynamic>> rows,
    String relationName,
  ) {
    return matchToMany(
      parents,
      rows,
      relationName,
      parentLocalKey,
      parentPivotKey,
      relatedPivotKey,
      pivotFields: pivotFields,
    );
  }
}
