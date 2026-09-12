import 'package:test/test.dart';
import 'package:vania/database.dart';

void main() {
  _mediumSeverityFixes();

  late MySqlAdapter adapter;

  setUp(() {
    adapter = MySqlAdapter();
  });

  group('MySqlAdapter renderCreateTable', () {
    test('simple table with id and string', () {
      const bp = TableBlueprint(
        tableName: 'users',
        columns: [
          ColumnBlueprint(
            name: 'id',
            type: ColumnType.bigInt,
            length: 20,
            unsigned: true,
            nullable: false,
            autoIncrement: true,
          ),
          ColumnBlueprint(
            name: 'name',
            type: ColumnType.varchar,
            length: 255,
            nullable: false,
          ),
        ],
        primaryKey: 'id',
        primaryAlgorithm: 'BTREE',
      );

      final stmts = adapter.renderCreateTable(bp);
      expect(stmts.length, 1);

      final sql = stmts.first;
      expect(sql, contains('CREATE TABLE `users`'));
      expect(sql, contains('`id` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT'));
      expect(sql, contains('`name` VARCHAR(255) NOT NULL'));
      expect(sql, contains('PRIMARY KEY (`id`) USING BTREE'));
    });

    test('IF NOT EXISTS clause', () {
      const bp = TableBlueprint(tableName: 'users');
      final stmts = adapter.renderCreateTable(bp, ifNotExists: true);
      expect(stmts.first, contains('CREATE TABLE IF NOT EXISTS `users`'));
    });

    test('foreign key rendering', () {
      const bp = TableBlueprint(
        tableName: 'posts',
        columns: [
          ColumnBlueprint(
            name: 'user_id',
            type: ColumnType.bigInt,
            nullable: false,
          ),
        ],
        foreignKeys: [
          ForeignKeyBlueprint(
            columnName: 'user_id',
            referencesTable: 'users',
            referencesColumn: 'id',
            onUpdate: 'CASCADE',
            onDelete: 'CASCADE',
          ),
        ],
      );

      final sql = adapter.renderCreateTable(bp).first;
      expect(sql, contains('CONSTRAINT `FK_posts_users`'));
      expect(sql, contains('FOREIGN KEY (`user_id`)'));
      expect(sql, contains('REFERENCES `users` (`id`)'));
      expect(sql, contains('ON UPDATE CASCADE ON DELETE CASCADE'));
    });

    test('index rendering', () {
      const bp = TableBlueprint(
        tableName: 'logs',
        indexes: [
          IndexBlueprint(
            name: 'idx_level',
            columns: ['level'],
            type: ColumnIndex.indexKey,
          ),
        ],
      );

      final sql = adapter.renderCreateTable(bp).first;
      expect(sql, contains('INDEX `idx_level` (`level`)'));
    });

    test('unique constraint rendering', () {
      const bp = TableBlueprint(
        tableName: 'users',
        uniqueConstraints: [
          UniqueConstraintBlueprint(name: 'uniq_email', columns: ['email']),
        ],
      );

      final sql = adapter.renderCreateTable(bp).first;
      expect(sql, contains('CONSTRAINT `uniq_email` UNIQUE (`email`)'));
    });

    test('uuid renders as CHAR(36)', () {
      const bp = TableBlueprint(
        tableName: 'items',
        columns: [
          ColumnBlueprint(name: 'uid', type: ColumnType.uuid, length: 36),
        ],
      );

      final sql = adapter.renderCreateTable(bp).first;
      expect(sql, contains('CHAR(36)'));
    });

    test('boolean renders as TINYINT(1)', () {
      const bp = TableBlueprint(
        tableName: 'items',
        columns: [ColumnBlueprint(name: 'active', type: ColumnType.boolean)],
      );

      final sql = adapter.renderCreateTable(bp).first;
      expect(sql, contains('TINYINT(1)'));
    });

    test('enum rendering', () {
      const bp = TableBlueprint(
        tableName: 'tickets',
        columns: [
          ColumnBlueprint(
            name: 'status',
            type: ColumnType.enumType,
            enumValues: ['open', 'closed'],
          ),
        ],
      );

      final sql = adapter.renderCreateTable(bp).first;
      expect(sql, contains("ENUM('open', 'closed')"));
    });

    test('default value rendering', () {
      const bp = TableBlueprint(
        tableName: 'users',
        columns: [
          ColumnBlueprint(
            name: 'role',
            type: ColumnType.varchar,
            length: 50,
            defaultValue: 'user',
          ),
        ],
      );

      final sql = adapter.renderCreateTable(bp).first;
      expect(sql, contains("DEFAULT 'user'"));
    });

    test('CURRENT_TIMESTAMP default', () {
      const bp = TableBlueprint(
        tableName: 'users',
        columns: [
          ColumnBlueprint(
            name: 'created_at',
            type: ColumnType.timestamp,
            defaultValue: 'CURRENT_TIMESTAMP',
          ),
        ],
      );

      final sql = adapter.renderCreateTable(bp).first;
      expect(sql, contains('DEFAULT CURRENT_TIMESTAMP'));
    });
  });

  group('MySqlAdapter renderDropTable', () {
    test('wraps with foreign key checks as separate statements', () {
      final stmts = adapter.renderDropTable('users', ifExists: true);
      expect(stmts.length, 3);
      expect(stmts[0], contains('FOREIGN_KEY_CHECKS=0'));
      expect(stmts[1], 'DROP TABLE IF EXISTS `users`');
      expect(stmts[2], contains('SET FOREIGN_KEY_CHECKS='));
      for (final stmt in stmts) {
        expect(stmt, isNot(contains(';')));
      }
    });
  });

  group('MySqlAdapter renderAlterAddColumns', () {
    test('adds column', () {
      const bp = TableBlueprint(
        tableName: 'users',
        columns: [
          ColumnBlueprint(
            name: 'email',
            type: ColumnType.varchar,
            length: 255,
            nullable: false,
          ),
        ],
      );

      final stmts = adapter.renderAlterAddColumns('users', bp);
      expect(stmts.length, 1);
      expect(stmts.first, contains('ALTER TABLE `users`'));
      expect(stmts.first, contains('ADD COLUMN `email` VARCHAR(255) NOT NULL'));
    });

    test('AFTER clause', () {
      const bp = TableBlueprint(
        tableName: 'users',
        columns: [ColumnBlueprint(name: 'bio', type: ColumnType.text)],
      );

      final stmts = adapter.renderAlterAddColumns(
        'users',
        bp,
        afterColumn: 'name',
      );
      expect(stmts.first, contains('AFTER `name`'));
    });
  });

  group('MySqlAdapter schema operations', () {
    test('renderDropColumn', () {
      final stmts = adapter.renderDropColumn('users', 'email');
      expect(stmts.first, 'ALTER TABLE `users` DROP COLUMN `email`');
    });

    test('renderRenameColumn', () {
      final stmts = adapter.renderRenameColumn('users', 'email', 'mail');
      expect(
        stmts.first,
        'ALTER TABLE `users` RENAME COLUMN `email` TO `mail`',
      );
    });

    test('renderRenameTable', () {
      final stmts = adapter.renderRenameTable('users', 'members');
      expect(stmts.first, 'RENAME TABLE `users` TO `members`');
    });

    test('renderAddIndex', () {
      const idx = IndexBlueprint(
        name: 'idx_email',
        columns: ['email'],
        type: ColumnIndex.unique,
      );
      final stmts = adapter.renderAddIndex('users', idx);
      expect(
        stmts.first,
        'CREATE UNIQUE INDEX `idx_email` ON `users` (`email`)',
      );
    });

    test('renderDropIndex', () {
      final stmts = adapter.renderDropIndex('users', 'idx_email');
      expect(stmts.first, 'DROP INDEX `idx_email` ON `users`');
    });
  });

  group('MySqlAdapter basics', () {
    test('driverName', () {
      expect(adapter.driverName, 'mysql');
    });

    test('supports', () {
      expect(adapter.supports('mysql'), true);
      expect(adapter.supports('pgsql'), false);
    });

    test('escapeIdentifier', () {
      expect(adapter.escapeIdentifier('table'), '`table`');
    });

    test('formatValue', () {
      expect(adapter.formatValue(null), 'NULL');
      expect(adapter.formatValue(42), '42');
      expect(adapter.formatValue(true), '1');
      expect(adapter.formatValue("it's"), "'it''s'");
    });
  });
}

void _mediumSeverityFixes() {
  final adapter = MySqlAdapter();

  group('MySqlAdapter literal escaping', () {
    test('escapes quotes in a column comment', () {
      const bp = TableBlueprint(
        tableName: 'users',
        columns: [
          ColumnBlueprint(
            name: 'name',
            type: ColumnType.varchar,
            comment: "the user's name",
          ),
        ],
      );

      final sql = adapter.renderCreateTable(bp).single;
      expect(sql, contains("COMMENT 'the user''s name'"));
    });

    test('escapes quotes in enum values', () {
      const bp = TableBlueprint(
        tableName: 'users',
        columns: [
          ColumnBlueprint(
            name: 'kind',
            type: ColumnType.enumType,
            enumValues: ["it's", 'plain'],
          ),
        ],
      );

      final sql = adapter.renderCreateTable(bp).single;
      expect(sql, contains("ENUM('it''s', 'plain')"));
    });
  });

  group('MySqlAdapter renderTableOptions', () {
    test('renders every option in a single ALTER', () {
      final stmts = adapter.renderTableOptions(
        'users',
        engine: 'InnoDB',
        charset: 'utf8mb4',
        collation: 'utf8mb4_unicode_ci',
        comment: 'people',
        autoIncrement: 100,
      );

      expect(stmts, hasLength(1));
      expect(stmts.single, startsWith('ALTER TABLE `users` '));
      expect(stmts.single, contains('ENGINE=InnoDB'));
      expect(stmts.single, contains('DEFAULT CHARSET=utf8mb4'));
      expect(stmts.single, contains('COLLATE=utf8mb4_unicode_ci'));
      expect(stmts.single, contains("COMMENT='people'"));
      expect(stmts.single, contains('AUTO_INCREMENT=100'));
    });

    test('escapes quotes in the table comment', () {
      final stmts = adapter.renderTableOptions('users', comment: "o'hara");
      expect(stmts.single, contains("COMMENT='o''hara'"));
    });

    test('returns nothing when no option was set', () {
      expect(adapter.renderTableOptions('users'), isEmpty);
    });
  });

  group('MySqlAdapter renderAlterAddColumns beforeColumn', () {
    test('throws rather than emitting an invalid BEFORE clause', () {
      const bp = TableBlueprint(
        tableName: 'users',
        columns: [ColumnBlueprint(name: 'age', type: ColumnType.integer)],
      );

      expect(
        () => adapter.renderAlterAddColumns('users', bp, beforeColumn: 'name'),
        throwsUnsupportedError,
      );
    });
  });
}
