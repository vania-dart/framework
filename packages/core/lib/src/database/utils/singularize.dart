class Singularize {
  static String make(String tableName) {
    if (tableName.isEmpty) return tableName;

    final name = tableName.toLowerCase();

    const irregularPlurals = {
      'children': 'child',
      'people': 'person',
      'men': 'man',
      'women': 'woman',
      'feet': 'foot',
      'teeth': 'tooth',
      'geese': 'goose',
      'mice': 'mouse',
      'oxen': 'ox',
      'sheep': 'sheep',
      'deer': 'deer',
      'fish': 'fish',
      'series': 'series',
      'species': 'species',
      'data': 'datum',
      'media': 'medium',
      'criteria': 'criterion',
      'phenomena': 'phenomenon',
      'alumni': 'alumnus',
      'cacti': 'cactus',
      'foci': 'focus',
      'fungi': 'fungus',
      'nuclei': 'nucleus',
      'radii': 'radius',
      'stimuli': 'stimulus',
      'syllabi': 'syllabus',
      'analyses': 'analysis',
      'bases': 'basis',
      'crises': 'crisis',
      'diagnoses': 'diagnosis',
      'hypotheses': 'hypothesis',
      'oases': 'oasis',
      'parentheses': 'parenthesis',
      'synopses': 'synopsis',
      'theses': 'thesis',
    };

    if (irregularPlurals.containsKey(name)) {
      return _preserveCase(tableName, irregularPlurals[name]!);
    }

    if (name.endsWith('ies') && name.length > 3) {
      return _preserveCase(tableName, '${name.substring(0, name.length - 3)}y');
    }

    if (name.endsWith('ves') && name.length > 3) {
      final stem = name.substring(0, name.length - 3);
      if (stem.endsWith('l') || stem.endsWith('r')) {
        return _preserveCase(tableName, '${stem}f');
      } else {
        return _preserveCase(tableName, '${stem}fe');
      }
    }

    if (name.endsWith('ses') && name.length > 3) {
      return _preserveCase(tableName, name.substring(0, name.length - 2));
    }
    if ((name.endsWith('ches') ||
            name.endsWith('shes') ||
            name.endsWith('xes') ||
            name.endsWith('zes')) &&
        name.length > 3) {
      return _preserveCase(tableName, name.substring(0, name.length - 2));
    }

    if (name.endsWith('oes') && name.length > 3) {
      return _preserveCase(tableName, name.substring(0, name.length - 2));
    }

    if (name.endsWith('i') && name.length > 2) {
      final stem = name.substring(0, name.length - 1);
      if (stem.endsWith('cact') ||
          stem.endsWith('fung') ||
          stem.endsWith('nucle') ||
          stem.endsWith('radi') ||
          stem.endsWith('stimul') ||
          stem.endsWith('syllab')) {
        return _preserveCase(tableName, '${stem}us');
      }
    }

    if (name.endsWith('a') && name.length > 2) {
      final stem = name.substring(0, name.length - 1);
      if (stem.endsWith('dat')) {
        return _preserveCase(tableName, '${stem}um');
      } else if (stem.endsWith('criteri') || stem.endsWith('phenomen')) {
        return _preserveCase(tableName, '${stem}on');
      }
    }

    if (name.endsWith('s') &&
        name.length > 1 &&
        !name.endsWith('ss') &&
        !name.endsWith('us') &&
        !name.endsWith('is')) {
      return _preserveCase(tableName, name.substring(0, name.length - 1));
    }

    return tableName;
  }

  static String pluralize(String word) {
    if (word.isEmpty) return word;

    final name = word.toLowerCase();

    const irregularSingulars = {
      'child': 'children',
      'person': 'people',
      'man': 'men',
      'woman': 'women',
      'foot': 'feet',
      'tooth': 'teeth',
      'goose': 'geese',
      'mouse': 'mice',
      'ox': 'oxen',
      'sheep': 'sheep',
      'deer': 'deer',
      'fish': 'fish',
      'series': 'series',
      'species': 'species',
      'datum': 'data',
      'medium': 'media',
      'criterion': 'criteria',
      'phenomenon': 'phenomena',
      'alumnus': 'alumni',
      'cactus': 'cacti',
      'focus': 'foci',
      'fungus': 'fungi',
      'nucleus': 'nuclei',
      'radius': 'radii',
      'stimulus': 'stimuli',
      'syllabus': 'syllabi',
      'analysis': 'analyses',
      'basis': 'bases',
      'crisis': 'crises',
      'diagnosis': 'diagnoses',
      'hypothesis': 'hypotheses',
      'oasis': 'oases',
      'parenthesis': 'parentheses',
      'synopsis': 'synopses',
      'thesis': 'theses',
    };

    if (irregularSingulars.containsKey(name)) {
      return _preserveCase(word, irregularSingulars[name]!);
    }

    if (name.endsWith('y') && name.length > 1) {
      final precedingChar = name[name.length - 2];
      if (!'aeiou'.contains(precedingChar)) {
        return _preserveCase(word, '${name.substring(0, name.length - 1)}ies');
      }
    }

    if (name.endsWith('f') && name.length > 1) {
      return _preserveCase(word, '${name.substring(0, name.length - 1)}ves');
    }
    if (name.endsWith('fe') && name.length > 2) {
      return _preserveCase(word, '${name.substring(0, name.length - 2)}ves');
    }

    if (name.endsWith('s') ||
        name.endsWith('ss') ||
        name.endsWith('sh') ||
        name.endsWith('ch') ||
        name.endsWith('x') ||
        name.endsWith('z')) {
      return _preserveCase(word, '${name}es');
    }

    if (name.endsWith('o') && name.length > 1) {
      final precedingChar = name[name.length - 2];
      if (!'aeiou'.contains(precedingChar)) {
        return _preserveCase(word, '${name}es');
      }
    }

    if (name.endsWith('us') && name.length > 2) {
      final stem = name.substring(0, name.length - 2);
      if (stem.endsWith('cact') ||
          stem.endsWith('foc') ||
          stem.endsWith('fung') ||
          stem.endsWith('nucle') ||
          stem.endsWith('radi') ||
          stem.endsWith('stimul') ||
          stem.endsWith('syllab')) {
        return _preserveCase(word, '${stem}i');
      }
    }

    if (name.endsWith('um') && name.length > 2) {
      final stem = name.substring(0, name.length - 2);
      if (stem.endsWith('dat')) {
        return _preserveCase(word, '${stem}a');
      }
    }

    if (name.endsWith('on') && name.length > 2) {
      final stem = name.substring(0, name.length - 2);
      if (stem.endsWith('criteri') || stem.endsWith('phenomen')) {
        return _preserveCase(word, '${stem}a');
      }
    }

    return _preserveCase(word, '${name}s');
  }

  static String _preserveCase(String original, String converted) {
    if (original.isEmpty || converted.isEmpty) return converted;

    if (original == original.toUpperCase()) {
      return converted.toUpperCase();
    }

    if (original[0] == original[0].toUpperCase()) {
      return '${converted[0].toUpperCase()}${converted.substring(1)}';
    }

    return converted;
  }

  static bool isPlural(String word) {
    if (word.isEmpty) return false;

    final name = word.toLowerCase();

    const irregularPlurals = {
      'children',
      'people',
      'men',
      'women',
      'feet',
      'teeth',
      'geese',
      'mice',
      'oxen',
      'data',
      'media',
      'criteria',
      'phenomena',
      'alumni',
      'cacti',
      'foci',
      'fungi',
      'nuclei',
      'radii',
      'stimuli',
      'syllabi',
      'analyses',
      'bases',
      'crises',
      'diagnoses',
      'hypotheses',
      'oases',
      'parentheses',
      'synopses',
      'theses',
    };

    if (irregularPlurals.contains(name)) return true;

    if (name.endsWith('ies') && name.length > 3) return true;
    if (name.endsWith('ves') && name.length > 3) return true;
    if (name.endsWith('ses') && name.length > 3) return true;
    if ((name.endsWith('ches') ||
            name.endsWith('shes') ||
            name.endsWith('xes') ||
            name.endsWith('zes')) &&
        name.length > 3) {
      return true;
    }
    if (name.endsWith('oes') && name.length > 3) return true;
    if (name.endsWith('s') &&
        name.length > 1 &&
        !name.endsWith('ss') &&
        !name.endsWith('us') &&
        !name.endsWith('is')) {
      return true;
    }

    return false;
  }

  static bool isSingular(String word) {
    return !isPlural(word);
  }
}
