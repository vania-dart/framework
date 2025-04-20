import '../../database/orm/model.dart';

abstract class Relation {
  final Model related;
  final Model parent;
  String? foreignKey;
  String localKey;

  Relation({
    required this.related,
    required this.parent,
    this.foreignKey,
    this.localKey = 'id',
  });

  Map<String, List<Map<String, dynamic>>> buildDictionary(
      List<Map<String, dynamic>> results, String key) {
    Map<String, List<Map<String, dynamic>>> dictionary = {};

    for (var result in results) {
      String modelKey = result[key].toString();
      if (!dictionary.containsKey(modelKey)) {
        dictionary[modelKey] = [];
      }
      dictionary[modelKey]!.add(result);
    }

    return dictionary;
  }

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

  /// Match many related models to parents (for normal relations)
  List<Map<String, dynamic>> matchMany(
    List<Map<String, dynamic>> models,
    List<Map<String, dynamic>> results,
    String relation,
    String parentKey,
    String relatedKey,
  ) {
    if (results.isEmpty || models.isEmpty) {
      return models;
    }
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
    for (var result in results) {
      if (result[typeKey]?.toString() == expectedType) {
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
    for (var result in results) {
      if (result[typeKey]?.toString().toLowerCase() == expectedType) {
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
