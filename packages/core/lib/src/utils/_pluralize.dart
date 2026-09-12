class Pluralize {
  static Pluralize? _singleton;

  factory Pluralize() {
    _singleton ??= Pluralize._internal();
    return _singleton!;
  }

  Pluralize._internal();

  final Map<String, String> irregulars = {
    'child': 'children',
    'goose': 'geese',
    'man': 'men',
    'woman': 'women',
    'tooth': 'teeth',
    'foot': 'feet',
    'mouse': 'mice',
    'person': 'people',
    'ox': 'oxen',
    'deer': 'deer',
    'sheep': 'sheep',
    'fish': 'fish',
    'series': 'series',
    'species': 'species',
    'aircraft': 'aircraft',
    'cactus': 'cacti',
    'analysis': 'analyses',
    'diagnosis': 'diagnoses',
    'ellipsis': 'ellipses',
    'phenomenon': 'phenomena',
    'criterion': 'criteria',
    'datum': 'data',
    'index': 'indices',
    'matrix': 'matrices',
    'vertex': 'vertices',
    'axis': 'axes',
    'die': 'dice',
    'bacterium': 'bacteria',
    'memorandum': 'memoranda',
    'curriculum': 'curricula',
    'formula': 'formulae',
    'addendum': 'addenda',
    'medium': 'media',
    'stratum': 'strata',
    'focus': 'foci',
    'alumnus': 'alumni',
    'genus': 'genera',
    'stimulus': 'stimuli',
    'automaton': 'automata',
    'thesis': 'theses',
    'crisis': 'crises',
    'appendix': 'appendices',
    'barracks': 'barracks',
    'headquarters': 'headquarters',
  };

  String make(String singular) {
    if (singular.isEmpty) return singular;

    if (singular.endsWith('ies') ||
        singular.endsWith('ses') ||
        singular.endsWith('xes') ||
        singular.endsWith('zes') ||
        singular.endsWith('ches') ||
        singular.endsWith('shes') ||
        singular.endsWith('oes')) {
      return singular;
    }

    if (irregulars.containsKey(singular.toLowerCase())) {
      String plural = irregulars[singular.toLowerCase()]!;

      if (singular[0].toUpperCase() == singular[0]) {
        return plural[0].toUpperCase() + plural.substring(1);
      }
      return plural;
    }

    if (singular.endsWith('y') &&
        singular.length > 1 &&
        !_isVowel(singular[singular.length - 2])) {
      return '${singular.substring(0, singular.length - 1)}ies';
    }

    if (singular.endsWith('s') ||
        singular.endsWith('x') ||
        singular.endsWith('z') ||
        singular.endsWith('ch') ||
        singular.endsWith('sh') ||
        (singular.endsWith('o') && !_isVowelBeforeO(singular))) {
      return '${singular}es';
    }

    return '${singular}s';
  }

  static bool _isVowel(String char) {
    return 'aeiou'.contains(char.toLowerCase());
  }

  static bool _isVowelBeforeO(String word) {
    if (word.length < 2 || !word.endsWith('o')) return false;
    return _isVowel(word[word.length - 2]);
  }

  String pluralizeVariableName(String variableName) {
    if (variableName.isEmpty) return variableName;

    if (variableName.contains('_')) {
      List<String> parts = variableName.split('_');
      parts[parts.length - 1] = make(parts.last);
      return parts.join('_');
    }

    RegExp camelCaseRegex = RegExp(r'[A-Z][a-z]*$');
    Match? match = camelCaseRegex.firstMatch(variableName);

    if (match != null && match.start > 0) {
      String lastWord = match.group(0)!;
      String pluralLastWord = make(lastWord);
      return variableName.substring(0, match.start) + pluralLastWord;
    } else {
      return make(variableName);
    }
  }
}
