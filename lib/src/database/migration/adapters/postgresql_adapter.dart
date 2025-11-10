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

  String _cleanedQuery = '';

  @override
  String adaptQuery(String query) {
    List<String> statements = adaptQueryToStatements(query);
    return statements.join(';\n');
  }

  List<String> adaptQueryToStatements(String query) {
    _extractTableNameAndIndexes(query);

    String result = _grammar.convertQuery(_cleanedQuery);

    List<String> statements = [result];

    if (_extractedIndexes.isNotEmpty && _currentTableName != null) {
      List<String> indexStatements = _generateIndexStatements();
      statements.addAll(indexStatements);
    }

    return statements;
  }

  Future<void> executeStatements(
    String query,
    Future<void> Function(List<String>) executor,
  ) async {
    List<String> statements = adaptQueryToStatements(query);
    await executor(statements);
  }

  void _extractTableNameAndIndexes(String query) {
    _extractedIndexes.clear();
    _currentTableName = null;

    final tableNameRegex = RegExp(
      r'CREATE TABLE (?:IF NOT EXISTS )?[`"]?([^`"]+)[`"]?\s*\(',
      caseSensitive: false,
    );
    final tableMatch = tableNameRegex.firstMatch(query);
    if (tableMatch != null) {
      _currentTableName = tableMatch.group(1);
    }

    final indexRegex = RegExp(
      r'((?:SPATIAL|FULLTEXT|UNIQUE)\s+)?INDEX\s+[`"]([^`"]+)[`"]\s*\(([^)]+)\)',
      caseSensitive: false,
    );
    final rawIndexes = indexRegex.allMatches(query).toList();
    for (final m in rawIndexes) {
      final typeKey = m.group(1)?.trim().toUpperCase() ?? '';
      final name = m.group(2)!;
      final cols = m.group(3)!;
      final cleanCols = cols
          .replaceAll(RegExp(r'[`"]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      _extractedIndexes.add('$name:$cleanCols:$typeKey');
    }
    query = query.replaceAll(indexRegex, '');
    query = query.replaceAll(RegExp(r',\s*\)'), ')');
    final constraintRegex = RegExp(
      r'CONSTRAINT\s+[`"]([^`"]+)[`"]\s+UNIQUE\s*\(([^)]+)\)',
      caseSensitive: false,
    );
    for (final m in constraintRegex.allMatches(query)) {
      final name = m.group(1)!;
      final cols = m.group(2)!;
      final cleanCols = cols
          .replaceAll(RegExp(r'[`"]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      _extractedIndexes.add('$name:$cleanCols:UNIQUE');
    }

    _cleanedQuery = query;
  }

  List<String> _generateIndexStatements() {
    final statements = <String>[];

    for (final info in _extractedIndexes) {
      final parts = info.split(':');
      final name = parts[0];
      final cols = parts[1];
      final typeKey = parts.length > 2 ? parts[2] : '';

      final colList = cols
          .split(',')
          .map((c) => '"${c.trim()}"')
          .toList()
          .join(', ');

      final prefix = typeKey.isNotEmpty ? '$typeKey ' : '';

      final stmt =
          'CREATE ${prefix}INDEX IF NOT EXISTS "$name" '
          'ON "$_currentTableName" ($colList)';
      statements.add(stmt);
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
