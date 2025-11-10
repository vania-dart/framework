import 'sql_grammar.dart';

class SqliteGrammar extends BaseGrammar {
  @override
  String get identifierQuote => '"';

  @override
  Map<String, String> get dataTypeMappings => {
    // Integer types - SQLite uses INTEGER for all integer types
    r'BIGINT\(\d+\)': 'INTEGER',
    r'MEDIUMINT\(\d+\)': 'INTEGER',
    r'SMALLINT\(\d+\)': 'INTEGER',
    r'TINYINT\(\d+\)': 'INTEGER',

    // Binary and bit types
    r'BINARY\(\d+\)': 'BLOB',
    r'VARBINARY\(\d+\)': 'BLOB',
    r'BIT\(\d+\)': 'INTEGER',

    // String types - SQLite uses TEXT for all string types
    r'VARCHAR\(\d+\)': 'TEXT',
    r'CHAR\(\d+\)': 'TEXT',

    // Date/time types - SQLite stores as TEXT or INTEGER
    'DATETIME': 'TEXT',
    'TIMESTAMP': 'TEXT',
    'DATE': 'TEXT',
    'TIME': 'TEXT',
    'YEAR': 'INTEGER',

    // BLOB types
    'TINYBLOB': 'BLOB',
    'BLOB': 'BLOB',
    'MEDIUMBLOB': 'BLOB',
    'LONGBLOB': 'BLOB',

    // Text types
    'TINYTEXT': 'TEXT',
    'MEDIUMTEXT': 'TEXT',
    'LONGTEXT': 'TEXT',

    // JSON - SQLite stores as TEXT
    'JSON': 'TEXT',
  };

  @override
  Map<String, String> get keywordReplacements => {
    'UNSIGNED': '',
    'ZEROFILL': '',
    'AUTO_INCREMENT': '',
    r"COLLATE\s+'[^']+'": '',
    r"ENGINE\s*=\s*\w+": '',
    r"COLLATE\s*=\s*'[^']+'": '',
  };

  @override
  Map<String, String Function(Match)> get regexTransformations => {
    // Auto-increment primary key transformation
    r'`(\w+)`\s+BIGINT\(\d+\)\s+UNSIGNED\s+NOT\s+NULL\s+AUTO_INCREMENT':
        (match) => '"${match[1]}" INTEGER PRIMARY KEY AUTOINCREMENT',

    // Remove primary key declarations (handled by AUTOINCREMENT)
    r'PRIMARY KEY \(`.*?`\) USING BTREE': (match) => '',
    r'PRIMARY KEY \(`.*?`\)': (match) => '',

    // Integer type with length
    r'(^|\s|,)INT\((\d+)\)': (match) => '${match[1]}INTEGER',
    r'(^|\s|,)INTEGER\((\d+)\)': (match) => '${match[1]}INTEGER',

    // Floating point types
    r'FLOAT\((\d+),(\d+)\)': (match) => 'REAL',
    r'DOUBLE\((\d+),(\d+)\)': (match) => 'REAL',
    r'DECIMAL\((\d+),(\d+)\)': (match) => 'REAL',

    // ENUM - SQLite doesn't have ENUM, use TEXT with CHECK constraint
    r'ENUM\(([^)]+)\)': (match) =>
        'TEXT CHECK (${_extractColumnName()} IN (${match[1]}))',
  };

  String _extractColumnName() {
    return 'column_name';
  }

  @override
  String convertQuery(String query) {
    String result = super.convertQuery(query);

    if (result.contains('TEXT CHECK (column_name IN')) {
      result = _handleEnumConstraints(query, result);
    }

    return result;
  }

  String _handleEnumConstraints(String originalQuery, String convertedQuery) {
    final enumMatch = RegExp(
      r'"?(\w+)"?\s+ENUM\(([^)]+)\)',
      caseSensitive: false,
    ).firstMatch(originalQuery);

    if (enumMatch != null) {
      final columnName = enumMatch.group(1);
      final enumValues = enumMatch.group(2);

      return convertedQuery.replaceAll(
        'TEXT CHECK (column_name IN ($enumValues))',
        'TEXT CHECK ("$columnName" IN ($enumValues))',
      );
    }

    return convertedQuery;
  }
}
