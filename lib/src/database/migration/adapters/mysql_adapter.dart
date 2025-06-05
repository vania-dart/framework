import '../contracts/database_adapter_interface.dart';
import 'grammar/mysql_grammar.dart';

class MySqlAdapter implements DatabaseAdapterInterface {
  late final MySqlGrammar _grammar;

  MySqlAdapter() {
    _grammar = MySqlGrammar();
  }

  @override
  String get driverName => 'mysql';

  @override
  String adaptQuery(String query) {
    return _grammar.convertQuery(query);
  }

  @override
  String getMigrationsTableSql() {
    return '''
CREATE TABLE IF NOT EXISTS `migrations` (
	`id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
	`migration` VARCHAR(255) NOT NULL COLLATE 'utf8mb4_unicode_ci',
	`batch` INT(10) UNSIGNED NOT NULL DEFAULT 1,
	PRIMARY KEY (`id`) USING BTREE
)
COLLATE='utf8mb4_unicode_ci'
ENGINE=InnoDB
;
''';
  }

  @override
  bool supports(String driver) {
    return driver.toLowerCase() == 'mysql';
  }

  @override
  String escapeIdentifier(String identifier) {
    return '`$identifier`';
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
