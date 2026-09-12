import 'package:vania/foundation.dart' show toSnakeCase;

import '../../orm/model.dart';

abstract class Relation {
  final Model related;
  final Model parent;
  String? foreignKey;
  String localKey;

  /// The conventional foreign key pointing at the parent, used when the
  /// relation was declared without an explicit `foreignKey`.
  String get parentForeignKey =>
      '${toSnakeCase(parent.runtimeType.toString())}_id';

  Relation({
    required this.related,
    required this.parent,
    this.foreignKey,
    this.localKey = 'id',
  });

  List<Map<String, dynamic>> match(
    List<Map<String, dynamic>> models,
    List<Map<String, dynamic>> results,
    String relation,
  );

  List<Map<String, dynamic>> matchOneOrMany(
    List<Map<String, dynamic>> models,
    List<Map<String, dynamic>> results,
    String relation,
    String parentKey,
    String relatedKey,
  ) {
    Map<String, Map<String, dynamic>> dictionary = {};

    for (var result in results) {
      String key = result[relatedKey].toString();
      dictionary[key] = result;
    }

    models = models.map((model) {
      String key = model[parentKey].toString();
      Map<String, dynamic> cloneModel = Map.from(model);
      if (dictionary.containsKey(key)) {
        cloneModel[relation] = dictionary[key];
      } else {
        cloneModel[relation] = null;
      }
      return cloneModel;
    }).toList();

    return models;
  }

  List<Map<String, dynamic>> matchToMany(
    List<Map<String, dynamic>> parents,
    List<Map<String, dynamic>> results,
    String relation,
    String parentLocalKey,
    String parentPivotKey,
    String relatedPivotKey, {
    List<String> pivotFields = const [],
  }) {
    final lookup = <dynamic, List<Map<String, dynamic>>>{};
    for (var row in results) {
      final pivotVal = row[parentPivotKey];
      lookup.putIfAbsent(pivotVal, () => []).add(row);
    }
    return parents.map((parent) {
      final cloned = Map<String, dynamic>.from(parent);
      final primaryVal = parent[parentLocalKey];
      final joinedRows = lookup[primaryVal] ?? [];

      final relatedList = joinedRows.map((row) {
        final relatedData = Map<String, dynamic>.from(row)
          ..remove(parentPivotKey)
          ..remove(relatedPivotKey)
          ..removeWhere((k, _) => pivotFields.contains(k));
        return relatedData;
      }).toList();

      cloned[relation] = relatedList;
      return cloned;
    }).toList();
  }

  /// Match many related models to parents (for normal relations)
  List<Map<String, dynamic>> matchMany(
    List<Map<String, dynamic>> models,
    List<Map<String, dynamic>> results,
    String relation,
    String parentKey,
    String relatedKey,
  ) {
    if (models.isEmpty) {
      return models;
    }
    // No early return on empty [results]: every parent still has to come
    // back carrying an empty list, not a missing key.
    Map<dynamic, List<Map<String, dynamic>>> dictionary = {};

    for (var result in results) {
      final key = result[relatedKey];
      if (!dictionary.containsKey(key)) {
        dictionary[key] = [];
      }
      dictionary[key]!.add(result);
    }

    models = models.map<Map<String, dynamic>>((Map<String, dynamic> model) {
      final key = model[parentKey];
      Map<String, dynamic> cloneModel = Map.from(model);
      if (dictionary.containsKey(key)) {
        cloneModel[relation] = dictionary[key];
      } else {
        cloneModel[relation] = [];
      }
      return cloneModel;
    }).toList();

    return models;
  }

  /// Match many related morph models to parents.
  /// Only includes results where the morph type (at column [typeKey]) equals [expectedType].
  List<Map<String, dynamic>> matchMorphMany(
    List<Map<String, dynamic>> models,
    List<Map<String, dynamic>> results,
    String relation,
    String parentKey,
    String relatedIdKey,
    String typeKey,
    String expectedType,
  ) {
    Map<String, List<Map<String, dynamic>>> dictionary = {};
    final type = expectedType.toLowerCase();
    for (var result in results) {
      if (result[typeKey]?.toString().toLowerCase() == type) {
        String key = result[relatedIdKey].toString();
        if (!dictionary.containsKey(key)) {
          dictionary[key] = [];
        }
        dictionary[key]!.add(result);
      }
    }

    models = models.map((model) {
      String key = model[parentKey].toString();
      Map<String, dynamic> cloneModel = Map.from(model);
      if (dictionary.containsKey(key)) {
        cloneModel[relation] = dictionary[key];
      } else {
        cloneModel[relation] = <Map<String, dynamic>>[];
      }
      return cloneModel;
    }).toList();

    return models;
  }

  List<Map<String, dynamic>> matchMorphToOne(
    List<Map<String, dynamic>> parents,
    List<Map<String, dynamic>> results,
    String relation,
    String morphKey,
    String relatedKey,
  ) {
    final dict = <String, Map<String, dynamic>>{};
    for (var row in results) {
      final key = row[relatedKey].toString();
      dict[key] = row;
    }
    return parents.map((parent) {
      final clone = Map<String, dynamic>.from(parent);
      final lookupKey = parent[morphKey]?.toString();
      clone[relation] = lookupKey != null ? dict[lookupKey] : null;
      return clone;
    }).toList();
  }

  /// Match one related morph model to parents (for hasOne polymorphic relation).
  /// Only includes results where [typeKey] equals [expectedType] and returns only the first matching result.
  List<Map<String, dynamic>> matchMorphOneOrMany(
    List<Map<String, dynamic>> models,
    List<Map<String, dynamic>> results,
    String relation,
    String parentKey,
    String relatedIdKey,
    String typeKey,
    String expectedType,
  ) {
    Map<String, Map<String, dynamic>> dictionary = {};
    final type = expectedType.toLowerCase();
    for (var result in results) {
      if (result[typeKey]?.toString().toLowerCase() == type) {
        String key = result[relatedIdKey].toString();
        if (!dictionary.containsKey(key)) {
          dictionary[key] = result;
        }
      }
    }
    models = models.map((model) {
      String key = model[parentKey].toString();
      Map<String, dynamic> cloneModel = Map.from(model);
      if (dictionary.containsKey(key)) {
        cloneModel[relation] = dictionary[key];
      } else {
        cloneModel[relation] = null;
      }
      return cloneModel;
    }).toList();

    return models;
  }
}
