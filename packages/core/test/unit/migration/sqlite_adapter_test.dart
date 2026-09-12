import 'package:test/test.dart';
import 'package:vania/database.dart';

void main() {
  _mediumSeverityFixes();

  late SqliteAdapter adapter;

  setUp(() {
    adapter = SqliteAdapter();
  });

  group('SqliteAdapter renderCreateTable', () {
    test('auto-increment uses INTEGER PRIMARY KEY AUTOINCREMENT', () {
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
      );

      final stmts = adapter.renderCreateTable(bp);

      final sql = stmts.first;
      expect(sql, contains('"id" INTEGER PRIMARY KEY AUTOINCREMENT'));
      expect(sql, contains('"name" TEXT NOT NULL'));
      // No separate PRIMARY KEY clause
      expect(sql, isNot(contains('PRIMARY KEY ("id")')));
    });

    test('varchar → TEXT', () {
      const bp = TableBlueprint(
        tableName: 'items',
        columns: [
          ColumnBlueprint(name: 'name', type: ColumnType.varchar, length: 100),
        ],
      );

      final sql = adapter.renderCreateTable(bp).first;
      expect(sql, contains('TEXT'));
      expect(sql, isNot(contains('VARCHAR')));
    });

    test('bigInt → INTEGER', () {
      const bp = TableBlueprint(
        tableName: 'items',
        columns: [ColumnBlueprint(name: 'count', type: ColumnType.bigInt)],
      );

      final sql = adapter.renderCreateTable(bp).first;
      expect(sql, contains('INTEGER'));
    });

    test('float/double/decimal → REAL', () {
      const bp = TableBlueprint(
        tableName: 'items',
        columns: [
          ColumnBlueprint(name: 'price', type: ColumnType.decimal),
          ColumnBlueprint(name: 'weight', type: ColumnType.float),
        ],
      );

      final sql = adapter.renderCreateTable(bp).first;
      expect('REAL'.allMatches(sql).length, 2);
    });

    test('blob types stay BLOB', () {
      const bp = TableBlueprint(
        tableName: 'files',
        columns: [
          ColumnBlueprint(name: 'data', type: ColumnType.blob),
          ColumnBlueprint(name: 'small', type: ColumnType.tinyBlob),
        ],
      );

      final sql = adapter.renderCreateTable(bp).first;
      expect('BLOB'.allMatches(sql).length, 2);
    });

    test('boolean → INTEGER', () {
      const bp = TableBlueprint(
        tableName: 'items',
        columns: [ColumnBlueprint(name: 'active', type: ColumnType.boolean)],
      );

      final sql = adapter.renderCreateTable(bp).first;
      expect(sql, contains('INTEGER'));
    });

    test('json → TEXT', () {
      const bp = TableBlueprint(
        tableName: 'items',
        columns: [ColumnBlueprint(name: 'meta', type: ColumnType.json)],
      );

      final sql = adapter.renderCreateTable(bp).first;
      expect(sql, contains('TEXT'));
    });

    test('enum renders with CHECK constraint', () {
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
      expect(sql, contains('CHECK'));
      expect(sql, contains("'open'"));
      expect(sql, contains("'closed'"));
    });

    test('indexes as separate statements', () {
      const bp = TableBlueprint(
        tableName: 'logs',
        indexes: [
          IndexBlueprint(
            name: 'idx_level',
            columns: ['level'],
            type: ColumnIndex.unique,
          ),
        ],
      );

      final stmts = adapter.renderCreateTable(bp);
      expect(stmts.length, 2);
      expect(stmts[1], contains('CREATE UNIQUE INDEX'));
    });

    test('foreign keys inline', () {
      const bp = TableBlueprint(
        tableName: 'posts',
        foreignKeys: [
          ForeignKeyBlueprint(
            columnName: 'user_id',
            referencesTable: 'users',
            referencesColumn: 'id',
          ),
        ],
      );

      final sql = adapter.renderCreateTable(bp).first;
      expect(sql, contains('FOREIGN KEY ("user_id")'));
      expect(sql, contains('REFERENCES "users" ("id")'));
    });
  });

  group('SqliteAdapter renderDropTable', () {
    test('simple drop', () {
      final stmts = adapter.renderDropTable('users', ifExists: true);
      expect(stmts.first, 'DROP TABLE IF EXISTS "users"');
    });
  });

  group('SqliteAdapter alter operations', () {
    test('renderAlterAddColumns', () {
      const bp = TableBlueprint(
        tableName: 'users',
        columns: [ColumnBlueprint(name: 'bio', type: ColumnType.text)],
      );

      final stmts = adapter.renderAlterAddColumns('users', bp);
      expect(stmts.first, contains('ALTER TABLE "users" ADD COLUMN "bio"'));
    });

    test('renderDropColumn', () {
      final stmts = adapter.renderDropColumn('users', 'bio');
      expect(stmts.first, 'ALTER TABLE "users" DROP COLUMN "bio"');
    });

    test('renderRenameTable', () {
      final stmts = adapter.renderRenameTable('old', 'new_table');
      expect(stmts.first, 'ALTER TABLE "old" RENAME TO "new_table"');
    });
  });

  group('SqliteAdapter basics', () {
    test('driverName', () {
      expect(adapter.driverName, 'sqlite');
    });

    test('supports', () {
      expect(adapter.supports('sqlite'), true);
      expect(adapter.supports('sqlite3'), true);
      expect(adapter.supports('mysql'), false);
    });

    test('formatValue', () {
      expect(adapter.formatValue(true), '1');
      expect(adapter.formatValue(false), '0');
    });
  });
}

void _mediumSeverityFixes() {
  final adapter = SqliteAdapter();

  group('SqliteAdapter renderAlterAddColumns unsupported changes', () {
    test('throws for a primary key', () {
      const bp = TableBlueprint(tableName: 'users', primaryKey: 'id');
      expect(
        () => adapter.renderAlterAddColumns('users', bp),
        throwsUnsupportedError,
      );
    });

    test('throws for a unique constraint', () {
      const bp = TableBlueprint(
        tableName: 'users',
        uniqueConstraints: [
          UniqueConstraintBlueprint(name: 'uq', columns: ['email']),
        ],
      );
      expect(
        () => adapter.renderAlterAddColumns('users', bp),
        throwsUnsupportedError,
      );
    });

    test('throws for a foreign key', () {
      const bp = TableBlueprint(
        tableName: 'posts',
        foreignKeys: [
          ForeignKeyBlueprint(
            columnName: 'user_id',
            referencesTable: 'users',
            referencesColumn: 'id',
          ),
        ],
      );
      expect(
        () => adapter.renderAlterAddColumns('posts', bp),
        throwsUnsupportedError,
      );
    });

    test('still adds plain columns', () {
      const bp = TableBlueprint(
        tableName: 'users',
        columns: [ColumnBlueprint(name: 'bio', type: ColumnType.text)],
      );
      expect(adapter.renderAlterAddColumns('users', bp), hasLength(1));
    });
  });

  group('SqliteAdapter enum escaping', () {
    test('escapes quotes in enum values and the column name', () {
      const bp = TableBlueprint(
        tableName: 'tickets',
        columns: [
          ColumnBlueprint(
            name: 'status',
            type: ColumnType.enumType,
            enumValues: ["it's", 'closed'],
          ),
        ],
      );

      final sql = adapter.renderCreateTable(bp).first;
      expect(sql, contains("""TEXT CHECK ("status" IN ('it''s', 'closed'))"""));
    });
  });

  group('SqliteGrammar enum conversion', () {
    test('rewrites every enum column, not just the first', () {
      final converted = adapter.adaptQuery(
        'CREATE TABLE `t` (`a` ENUM(\'x\',\'y\'), `b` ENUM(\'p\',\'q\'))',
      );

      expect(converted, contains('"a" TEXT CHECK ("a" IN (\'x\',\'y\'))'));
      expect(converted, contains('"b" TEXT CHECK ("b" IN (\'p\',\'q\'))'));
      expect(converted, isNot(contains('column_name')));
    });
  });
}
