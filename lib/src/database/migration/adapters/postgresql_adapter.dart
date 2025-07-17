import '../contracts/database_adapter_interface.dart';
import 'grammar/postgresql_grammar.dart';

class PostgreSqlAdapter implements DatabaseAdapterInterface {
  late final PostgreSqlGrammar _grammar;
  final List<String> _extractedIndexes = [];
  String? _currentTableName;

  PostgreSqlAdapter() {
    _grammar = PostgreSqlGrammar();
  }

  @override
  String get driverName => 'pgsql';

  @override
  String adaptQuery(String query) {
    List<String> statements = adaptQueryToStatements(query);
    return statements.join(';\n');
  }

  List<String> adaptQueryToStatements(String query) {
    _extractTableNameAndIndexes(query);

    String result = _grammar.convertQuery(query);

    List<String> statements = [result];

    if (_extractedIndexes.isNotEmpty && _currentTableName != null) {
      List<String> indexStatements = _generateIndexStatements();
      statements.addAll(indexStatements);
    }

    return statements;
  }

  Future<void> executeStatements(
      String query, Future<void> Function(List<String>) executor) async {
    List<String> statements = adaptQueryToStatements(query);
    await executor(statements);
  }

  void _extractTableNameAndIndexes(String query) {
    _extractedIndexes.clear();
    _currentTableName = null;

    RegExp tableNameRegex = RegExp(
        r'CREATE TABLE (?:IF NOT EXISTS )?[`"]?([^`"]+)[`"]?\s*\(',
        caseSensitive: false);
    Match? tableMatch = tableNameRegex.firstMatch(query);
    if (tableMatch != null) {
      _currentTableName = tableMatch.group(1);
    }

    RegExp indexRegex =
        RegExp(r'INDEX\s+[`"]([^`"]+)[`"]\s*\(([^)]+)\)', caseSensitive: false);
    Iterable<Match> indexMatches = indexRegex.allMatches(query);

    for (Match match in indexMatches) {
      String indexName = match.group(1)!;
      String columns = match.group(2)!;
      String cleanColumns = columns
          .replaceAll(RegExp(r'[`"]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      _extractedIndexes.add('$indexName:$cleanColumns');
    }

    RegExp constraintRegex = RegExp(
        r'CONSTRAINT\s+[`"]([^`"]+)[`"]\s+UNIQUE\s*\(([^)]+)\)',
        caseSensitive: false);
    Iterable<Match> constraintMatches = constraintRegex.allMatches(query);

    for (Match match in constraintMatches) {
      String constraintName = match.group(1)!;
      String columns = match.group(2)!;
      String cleanColumns = columns
          .replaceAll(RegExp(r'[`"]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      _extractedIndexes.add('$constraintName:$cleanColumns:UNIQUE');
    }
  }

  List<String> _generateIndexStatements() {
    List<String> statements = [];

    for (String indexInfo in _extractedIndexes) {
      List<String> parts = indexInfo.split(':');
      String indexName = parts[0];
      String columns = parts[1];
      bool isUnique = parts.length > 2 && parts[2] == 'UNIQUE';

      List<String> columnList =
          columns.split(',').map((col) => '"${col.trim()}"').toList();
      String formattedColumns = columnList.join(', ');

      String uniqueKeyword = isUnique ? 'UNIQUE ' : '';
      String statement =
          'CREATE ${uniqueKeyword}INDEX IF NOT EXISTS "$indexName" ON "$_currentTableName" ($formattedColumns)';
      statements.add(statement);
    }

    return statements;
  }

  @override
  String getMigrationsTableSql() {
    return '''
CREATE TABLE IF NOT EXISTS "migrations" (
	"id" SERIAL NOT NULL PRIMARY KEY,
	"migration" VARCHAR(255) NOT NULL,
	"batch" INTEGER NOT NULL DEFAULT 1
);
''';
  }

  @override
  bool supports(String driver) {
    final normalizedDriver = driver.toLowerCase();
    return normalizedDriver == 'pgsql' ||
        normalizedDriver == 'postgresql' ||
        normalizedDriver == 'postgres';
  }

  @override
  String escapeIdentifier(String identifier) {
    return '"$identifier"';
  }

  @override
  String formatValue(dynamic value) {
    if (value == null) return 'NULL';
    if (value is String) return "'${value.replaceAll("'", "''")}'";
    if (value is num) return value.toString();
    if (value is bool) return value ? 'TRUE' : 'FALSE';
    return "'$value'";
  }
}
