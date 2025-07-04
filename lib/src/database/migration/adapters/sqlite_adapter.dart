import '../contracts/database_adapter_interface.dart';
import 'grammar/sqlite_grammar.dart';

class SqliteAdapter implements DatabaseAdapterInterface {
  late final SqliteGrammar _grammar;

  SqliteAdapter() {
    _grammar = SqliteGrammar();
  }

  @override
  String get driverName => 'sqlite';

  @override
  String adaptQuery(String query) {
    return _grammar.convertQuery(query);
  }

  @override
  String getMigrationsTableSql() {
    return '''
CREATE TABLE IF NOT EXISTS "migrations" (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT,
	"migration" TEXT NOT NULL,
	"batch" INTEGER NOT NULL DEFAULT 1
);
''';
  }

  @override
  bool supports(String driver) {
    final normalizedDriver = driver.toLowerCase();
    return normalizedDriver == 'sqlite' || normalizedDriver == 'sqlite3';
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
    if (value is bool) return value ? '1' : '0';
    return "'$value'";
  }
}
