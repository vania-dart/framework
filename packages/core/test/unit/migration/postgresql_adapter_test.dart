import 'package:test/test.dart';
import 'package:vania/database.dart';

void main() {
  _mediumSeverityFixes();

  late PostgreSqlAdapter adapter;

  setUp(() {
    adapter = PostgreSqlAdapter();
  });

  group('PostgreSqlAdapter renderCreateTable', () {
    test('auto-increment primary key becomes SERIAL', () {
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
      expect(stmts.length, 1);

      final sql = stmts.first;
      expect(sql, contains('CREATE TABLE "users"'));
      expect(sql, contains('"id" SERIAL NOT NULL PRIMARY KEY'));
      expect(sql, contains('"name" VARCHAR(255) NOT NULL'));
      // No separate PRIMARY KEY clause when SERIAL is used
      expect(sql, isNot(contains('PRIMARY KEY ("id")')));
    });

    test('IF NOT EXISTS clause', () {
      const bp = TableBlueprint(tableName: 'users');
      final stmts = adapter.renderCreateTable(bp, ifNotExists: true);
      expect(stmts.first, contains('CREATE TABLE IF NOT EXISTS "users"'));
    });

    test('indexes are separate CREATE INDEX statements', () {
      const bp = TableBlueprint(
        tableName: 'logs',
        columns: [
          ColumnBlueprint(name: 'level', type: ColumnType.varchar, length: 50),
        ],
        indexes: [
          IndexBlueprint(
            name: 'idx_level',
            columns: ['level'],
            type: ColumnIndex.indexKey,
          ),
        ],
      );

      final stmts = adapter.renderCreateTable(bp);
      expect(stmts.length, 2);
      expect(stmts[0], contains('CREATE TABLE "logs"'));
      expect(stmts[1], contains('CREATE INDEX IF NOT EXISTS "idx_level"'));
      expect(stmts[1], contains('ON "logs" ("level")'));
    });

    test('uuid renders as UUID type', () {
      const bp = TableBlueprint(
        tableName: 'items',
        columns: [
          ColumnBlueprint(name: 'uid', type: ColumnType.uuid, length: 36),
        ],
      );

      final sql = adapter.renderCreateTable(bp).first;
      expect(sql, contains('UUID'));
      expect(sql, isNot(contains('CHAR(36)')));
    });

    test('boolean renders as BOOLEAN', () {
      const bp = TableBlueprint(
        tableName: 'items',
        columns: [ColumnBlueprint(name: 'active', type: ColumnType.boolean)],
      );

      final sql = adapter.renderCreateTable(bp).first;
      expect(sql, contains('BOOLEAN'));
      expect(sql, isNot(contains('TINYINT')));
    });

    test('json renders as JSONB', () {
      const bp = TableBlueprint(
        tableName: 'items',
        columns: [ColumnBlueprint(name: 'meta', type: ColumnType.json)],
      );

      final sql = adapter.renderCreateTable(bp).first;
      expect(sql, contains('JSONB'));
    });

    test('blob types render as BYTEA', () {
      const bp = TableBlueprint(
        tableName: 'files',
        columns: [
          ColumnBlueprint(name: 'data', type: ColumnType.blob),
          ColumnBlueprint(name: 'thumb', type: ColumnType.mediumBlob),
        ],
      );

      final sql = adapter.renderCreateTable(bp).first;
      expect(sql, contains('"data" BYTEA'));
      expect(sql, contains('"thumb" BYTEA'));
    });

    test('tinyInt renders as SMALLINT', () {
      const bp = TableBlueprint(
        tableName: 'flags',
        columns: [ColumnBlueprint(name: 'flag', type: ColumnType.tinyInt)],
      );

      final sql = adapter.renderCreateTable(bp).first;
      expect(sql, contains('SMALLINT'));
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
          ),
        ],
      );

      final sql = adapter.renderCreateTable(bp).first;
      expect(sql, contains('CONSTRAINT "FK_posts_users"'));
      expect(sql, contains('FOREIGN KEY ("user_id")'));
      expect(sql, contains('REFERENCES "users" ("id")'));
    });

    test('UUID() default becomes gen_random_uuid()', () {
      const bp = TableBlueprint(
        tableName: 'items',
        columns: [
          ColumnBlueprint(
            name: 'uid',
            type: ColumnType.uuid,
            defaultValue: 'UUID()',
          ),
        ],
      );

      final sql = adapter.renderCreateTable(bp).first;
      expect(sql, contains('DEFAULT gen_random_uuid()'));
    });
  });

  group('PostgreSqlAdapter renderDropTable', () {
    test('includes CASCADE', () {
      final stmts = adapter.renderDropTable('users', ifExists: true);
      expect(stmts.first, 'DROP TABLE IF EXISTS "users" CASCADE');
    });
  });

  group('PostgreSqlAdapter alter operations', () {
    test('renderAlterAddColumns produces separate statements', () {
      const bp = TableBlueprint(
        tableName: 'users',
        columns: [
          ColumnBlueprint(name: 'email', type: ColumnType.varchar, length: 255),
          ColumnBlueprint(name: 'bio', type: ColumnType.text),
        ],
      );

      final stmts = adapter.renderAlterAddColumns('users', bp);
      expect(stmts.length, 2);
      expect(stmts[0], contains('ALTER TABLE "users" ADD COLUMN "email"'));
      expect(stmts[1], contains('ALTER TABLE "users" ADD COLUMN "bio"'));
    });

    test('renderDropColumn', () {
      final stmts = adapter.renderDropColumn('users', 'email');
      expect(stmts.first, 'ALTER TABLE "users" DROP COLUMN "email"');
    });

    test('renderRenameColumn', () {
      final stmts = adapter.renderRenameColumn('users', 'email', 'mail');
      expect(
        stmts.first,
        'ALTER TABLE "users" RENAME COLUMN "email" TO "mail"',
      );
    });

    test('renderRenameTable', () {
      final stmts = adapter.renderRenameTable('users', 'members');
      expect(stmts.first, 'ALTER TABLE "users" RENAME TO "members"');
    });

    test('renderDropIndex', () {
      final stmts = adapter.renderDropIndex('users', 'idx_email');
      expect(stmts.first, 'DROP INDEX IF EXISTS "idx_email"');
    });
  });

  group('PostgreSqlAdapter basics', () {
    test('driverName', () {
      expect(adapter.driverName, 'pgsql');
    });

    test('supports', () {
      expect(adapter.supports('pgsql'), true);
      expect(adapter.supports('postgresql'), true);
      expect(adapter.supports('postgres'), true);
      expect(adapter.supports('mysql'), false);
    });

    test('escapeIdentifier', () {
      expect(adapter.escapeIdentifier('table'), '"table"');
    });

    test('formatValue booleans use TRUE/FALSE', () {
      expect(adapter.formatValue(true), 'TRUE');
      expect(adapter.formatValue(false), 'FALSE');
    });
  });
}

void _mediumSeverityFixes() {
  final adapter = PostgreSqlAdapter();

  group('PostgreSqlAdapter column comments', () {
    const bp = TableBlueprint(
      tableName: 'users',
      columns: [
        ColumnBlueprint(
          name: 'name',
          type: ColumnType.varchar,
          comment: "the user's name",
        ),
        ColumnBlueprint(name: 'age', type: ColumnType.integer),
      ],
    );

    test('emits COMMENT ON COLUMN instead of dropping the comment', () {
      final stmts = adapter.renderCreateTable(bp);

      expect(
        stmts,
        contains('COMMENT ON COLUMN "users"."name" IS \'the user\'\'s name\''),
      );
      expect(stmts.where((s) => s.contains('"users"."age"')), isEmpty);
    });

    test('also emits comments for columns added via ALTER', () {
      final stmts = adapter.renderAlterAddColumns('users', bp);

      expect(stmts.any((s) => s.startsWith('COMMENT ON COLUMN')), isTrue);
    });
  });

  group('PostgreSqlAdapter renderTableOptions', () {
    test('maps a table comment to COMMENT ON TABLE', () {
      final stmts = adapter.renderTableOptions('users', comment: 'people');

      expect(stmts.single, 'COMMENT ON TABLE "users" IS \'people\'');
    });

    test('drops MySQL-only options rather than emitting invalid SQL', () {
      final stmts = adapter.renderTableOptions(
        'users',
        engine: 'InnoDB',
        charset: 'utf8mb4',
        collation: 'utf8mb4_unicode_ci',
        autoIncrement: 10,
      );

      expect(stmts, isEmpty);
    });
  });
}
