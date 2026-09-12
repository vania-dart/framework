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

    // ENUM - SQLite has no ENUM, so use TEXT plus a CHECK constraint. The
    // column name is captured alongside the type so every enum column in the
    // statement is rewritten, not just the first.
    r'[`"](\w+)[`"](\s+)ENUM\(([^)]+)\)': (match) =>
        '"${match[1]}"${match[2]}TEXT CHECK ("${match[1]}" IN (${match[3]}))',
  };
}
