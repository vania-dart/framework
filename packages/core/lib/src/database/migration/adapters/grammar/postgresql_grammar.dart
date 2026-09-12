import 'sql_grammar.dart';

/// PostgreSQL-specific SQL grammar (Single Responsibility Principle)
class PostgreSqlGrammar extends BaseGrammar {
  @override
  String get identifierQuote => '"';

  @override
  Map<String, String> get dataTypeMappings => {
    // Integer types
    r'BIGINT\(\d+\)': 'BIGINT',
    r'MEDIUMINT\(\d+\)': 'INTEGER',
    r'SMALLINT\(\d+\)': 'SMALLINT',
    r'TINYINT\(\d+\)': 'SMALLINT',

    // Binary types
    r'BINARY\(\d+\)': 'BYTEA',
    r'VARBINARY\(\d+\)': 'BYTEA',
    r'BIT\(\d+\)': 'BOOLEAN',

    // Date/time types
    r'DATETIME\(\d+\)': 'TIMESTAMP',
    r'TIME\(\d+\)': 'TIME',

    // Floating point types
    r'DOUBLE\(\d+\)': 'DOUBLE PRECISION',

    // BLOB types
    'TINYBLOB': 'BYTEA',
    'BLOB': 'BYTEA',
    'MEDIUMBLOB': 'BYTEA',
    'LONGBLOB': 'BYTEA',
    'VARBYTEA': 'BYTEA',
    'MEDIUMBYTEA': 'BYTEA',
    'LONGBYTEA': 'BYTEA',

    // Text types
    'TINYTEXT': 'TEXT',
    'MEDIUMTEXT': 'TEXT',
    r'LONGTEXT\(\d+\)': 'TEXT',

    // Geometry types
    'LINESTRING': 'LINE',
  };

  @override
  Map<String, String> get keywordReplacements => {
    'UNSIGNED': '',
    'ZEROFILL': '',
    'AUTO_INCREMENT': '',
    r"COLLATE '[\w\d_-]+'": '',
    r"ENGINE\s*=\s*\w+": '',
    r"COMMENT\s+'[^']*'": '',
  };

  @override
  Map<String, String Function(Match)> get regexTransformations => {
    // Auto-increment primary key transformation - handle table.id() pattern
    r'[`"](\w+)[`"]\s+BIGINT(?:\(\d+\))?\s+(?:UNSIGNED\s+)?NOT\s+NULL\s+AUTO_INCREMENT':
        (match) => '"${match[1]}" SERIAL NOT NULL PRIMARY KEY',

    r'\s+ON\s+UPDATE\s+CURRENT_TIMESTAMP': (match) => '',
    r'ON\s+UPDATE\s+CURRENT_TIMESTAMP': (match) => '',

    // Handle `BIGINT` NOT NULL without AUTO_INCREMENT but with separate PRIMARY KEY
    r'[`"](\w+)[`"]\s+BIGINT(?:\(\d+\))?\s+(?:UNSIGNED\s+)?NOT\s+NULL(?!\s+AUTO_INCREMENT)':
        (match) => '"${match[1]}" BIGINT NOT NULL',

    // Remove primary key declarations when SERIAL is used
    r',\s*PRIMARY KEY \([`"][^`"]+[`"]\)': (match) => '',
    r'PRIMARY KEY \([`"][^`"]+[`"]\)\s*,?': (match) => '',

    // Remove INDEX declarations - more comprehensive patterns
    r',\s*INDEX\s+[`"][^`"]*[`"]\s*\([^)]*\)': (match) => '',
    r'INDEX\s+[`"][^`"]*[`"]\s*\([^)]*\)\s*,': (match) => '',
    r'INDEX\s+[`"][^`"]*[`"]\s*\([^)]*\)': (match) => '',

    // Remove CONSTRAINT UNIQUE (will be handled by adapter)
    r',\s*CONSTRAINT\s+[`"][^`"]*[`"]\s+UNIQUE\s*\([^)]*\)': (match) => '',
    r'CONSTRAINT\s+[`"][^`"]*[`"]\s+UNIQUE\s*\([^)]*\)\s*,': (match) => '',
    r'CONSTRAINT\s+[`"][^`"]*[`"]\s+UNIQUE\s*\([^)]*\)': (match) => '',

    // Integer type with length
    r'(^|\s|,)INT\((\d+)\)': (match) => '${match[1]}INTEGER',
    r'(^|\s|,)INTEGER\((\d+)\)': (match) => '${match[1]}INTEGER',

    // VARCHAR with length preservation
    r'VARCHAR\((\d+)\)': (match) => 'VARCHAR(${match[1]})',
    r'VARCHARACTER\((\d+)\)': (match) => 'CHARACTER(${match[1]})',

    // FLOAT conversion
    r'FLOAT\((\d+)\)': (match) => 'REAL',

    // ENUM to VARCHAR conversion
    r"ENUM\((?:'[^']*'(?:\s*,\s*'[^']*')*)\)": (match) => 'VARCHAR',

    // Clean up empty spaces and commas that result from removals
    r',\s*,+': (match) => ',',
    r'^\s*,': (match) => '',
    r',\s*\)': (match) => ')',
    r'\(\s*,': (match) => '(',
  };

  @override
  String convertQuery(String query) {
    String result = super.convertQuery(query);

    // Additional PostgreSQL-specific cleanup
    result = _postgresqlSpecificCleanup(result);

    return result;
  }

  /// PostgreSQL-specific cleanup operations
  String _postgresqlSpecificCleanup(String query) {
    return query
        // Remove any remaining double commas
        .replaceAll(RegExp(r',\s*,+'), ',')
        // Remove leading commas
        .replaceAll(RegExp(r'^\s*,'), '')
        // Remove trailing commas before closing parenthesis
        .replaceAll(RegExp(r',\s*\)'), ')')
        // Remove extra spaces
        .replaceAll(RegExp(r'\s+'), ' ')
        // Clean up any remaining issues
        .trim();
  }
}
