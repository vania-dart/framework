import 'dart:convert';

import 'package:test/test.dart';
import 'package:vania/database.dart';

void main() {
  late MongoAdapter adapter;

  setUp(() {
    adapter = MongoAdapter();
  });

  group('MongoAdapter renderCreateTable', () {
    test('generates createCollection JSON command', () {
      const bp = TableBlueprint(
        tableName: 'users',
        columns: [
          ColumnBlueprint(
            name: 'name',
            type: ColumnType.varchar,
            nullable: false,
          ),
          ColumnBlueprint(
            name: 'email',
            type: ColumnType.varchar,
            nullable: false,
          ),
        ],
      );

      final stmts = adapter.renderCreateTable(bp);
      expect(stmts.isNotEmpty, true);

      final cmd = jsonDecode(stmts.first) as Map<String, dynamic>;
      expect(cmd['_vania_migration'], 'createCollection');
      expect(cmd['name'], 'users');

      final validator = cmd['options']['validator'] as Map<String, dynamic>;
      final schema = validator['\$jsonSchema'] as Map<String, dynamic>;
      expect(schema['bsonType'], 'object');
      expect(schema['required'], contains('name'));
      expect(schema['required'], contains('email'));

      final props = schema['properties'] as Map<String, dynamic>;
      expect(props['name']['bsonType'], 'string');
      expect(props['email']['bsonType'], 'string');
    });

    test('nullable columns are NOT in required', () {
      const bp = TableBlueprint(
        tableName: 'users',
        columns: [
          ColumnBlueprint(name: 'bio', type: ColumnType.text, nullable: true),
        ],
      );

      final cmd = jsonDecode(adapter.renderCreateTable(bp).first);
      final schema = cmd['options']['validator']['\$jsonSchema'];
      expect(schema.containsKey('required'), false);
    });

    test('indexes become createIndex commands', () {
      const bp = TableBlueprint(
        tableName: 'users',
        indexes: [
          IndexBlueprint(
            name: 'idx_email',
            columns: ['email'],
            type: ColumnIndex.unique,
          ),
        ],
      );

      final stmts = adapter.renderCreateTable(bp);
      expect(stmts.length, greaterThanOrEqualTo(2));

      final idxCmd = jsonDecode(stmts[1]) as Map<String, dynamic>;
      expect(idxCmd['_vania_migration'], 'createIndex');
      expect(idxCmd['collection'], 'users');
      expect(idxCmd['keys']['email'], 1);
      expect(idxCmd['options']['unique'], true);
      expect(idxCmd['options']['name'], 'idx_email');
    });

    test('unique constraints become unique indexes', () {
      const bp = TableBlueprint(
        tableName: 'users',
        uniqueConstraints: [
          UniqueConstraintBlueprint(
            name: 'uniq_email_org',
            columns: ['email', 'org_id'],
          ),
        ],
      );

      final stmts = adapter.renderCreateTable(bp);
      final found = stmts.any((s) {
        final cmd = jsonDecode(s);
        return cmd['_vania_migration'] == 'createIndex' &&
            cmd['options']['unique'] == true &&
            cmd['options']['name'] == 'uniq_email_org';
      });
      expect(found, true);
    });

    test('bsonType mapping for integer', () {
      const bp = TableBlueprint(
        tableName: 'items',
        columns: [ColumnBlueprint(name: 'count', type: ColumnType.integer)],
      );

      final cmd = jsonDecode(adapter.renderCreateTable(bp).first);
      final props = cmd['options']['validator']['\$jsonSchema']['properties'];
      expect(props['count']['bsonType'], 'int');
    });

    test('bsonType mapping for boolean', () {
      const bp = TableBlueprint(
        tableName: 'items',
        columns: [ColumnBlueprint(name: 'active', type: ColumnType.boolean)],
      );

      final cmd = jsonDecode(adapter.renderCreateTable(bp).first);
      final props = cmd['options']['validator']['\$jsonSchema']['properties'];
      expect(props['active']['bsonType'], 'bool');
    });

    test('bsonType mapping for json/object', () {
      const bp = TableBlueprint(
        tableName: 'items',
        columns: [ColumnBlueprint(name: 'meta', type: ColumnType.json)],
      );

      final cmd = jsonDecode(adapter.renderCreateTable(bp).first);
      final props = cmd['options']['validator']['\$jsonSchema']['properties'];
      expect(props['meta']['bsonType'], 'object');
    });

    test('bsonType mapping for date/timestamp', () {
      const bp = TableBlueprint(
        tableName: 'events',
        columns: [
          ColumnBlueprint(name: 'created_at', type: ColumnType.timestamp),
          ColumnBlueprint(name: 'event_date', type: ColumnType.date),
        ],
      );

      final cmd = jsonDecode(adapter.renderCreateTable(bp).first);
      final props = cmd['options']['validator']['\$jsonSchema']['properties'];
      expect(props['created_at']['bsonType'], 'date');
      expect(props['event_date']['bsonType'], 'date');
    });

    test('bsonType mapping for binary/blob', () {
      const bp = TableBlueprint(
        tableName: 'files',
        columns: [ColumnBlueprint(name: 'data', type: ColumnType.blob)],
      );

      final cmd = jsonDecode(adapter.renderCreateTable(bp).first);
      final props = cmd['options']['validator']['\$jsonSchema']['properties'];
      expect(props['data']['bsonType'], 'binData');
    });

    test('enum values in schema', () {
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

      final cmd = jsonDecode(adapter.renderCreateTable(bp).first);
      final props = cmd['options']['validator']['\$jsonSchema']['properties'];
      expect(props['status']['enum'], ['open', 'closed']);
    });
  });

  group('MongoAdapter renderDropTable', () {
    test('generates dropCollection JSON command', () {
      final stmts = adapter.renderDropTable('users');
      final cmd = jsonDecode(stmts.first);
      expect(cmd['_vania_migration'], 'dropCollection');
      expect(cmd['name'], 'users');
    });
  });

  group('MongoAdapter alter operations', () {
    test('renderDropColumn generates removeField', () {
      final stmts = adapter.renderDropColumn('users', 'email');
      final cmd = jsonDecode(stmts.first);
      expect(cmd['_vania_migration'], 'removeField');
      expect(cmd['collection'], 'users');
      expect(cmd['field'], 'email');
    });

    test('renderRenameColumn generates renameField', () {
      final stmts = adapter.renderRenameColumn('users', 'email', 'mail');
      final cmd = jsonDecode(stmts.first);
      expect(cmd['_vania_migration'], 'renameField');
      expect(cmd['oldName'], 'email');
      expect(cmd['newName'], 'mail');
    });

    test('renderRenameTable generates renameCollection', () {
      final stmts = adapter.renderRenameTable('users', 'members');
      final cmd = jsonDecode(stmts.first);
      expect(cmd['_vania_migration'], 'renameCollection');
      expect(cmd['oldName'], 'users');
      expect(cmd['newName'], 'members');
    });

    test('renderAddIndex generates createIndex', () {
      const idx = IndexBlueprint(
        name: 'idx_email',
        columns: ['email'],
        type: ColumnIndex.unique,
      );
      final stmts = adapter.renderAddIndex('users', idx);
      final cmd = jsonDecode(stmts.first);
      expect(cmd['_vania_migration'], 'createIndex');
      expect(cmd['collection'], 'users');
      expect(cmd['keys']['email'], 1);
      expect(cmd['options']['unique'], true);
    });

    test('renderDropIndex generates dropIndex', () {
      final stmts = adapter.renderDropIndex('users', 'idx_email');
      final cmd = jsonDecode(stmts.first);
      expect(cmd['_vania_migration'], 'dropIndex');
      expect(cmd['indexName'], 'idx_email');
    });
  });

  group('MongoAdapter basics', () {
    test('driverName', () {
      expect(adapter.driverName, 'mongodb');
    });

    test('supports', () {
      expect(adapter.supports('mongodb'), true);
      expect(adapter.supports('mongo'), true);
      expect(adapter.supports('mysql'), false);
    });

    test('getMigrationsTableSql returns createCollection command', () {
      final cmd = jsonDecode(adapter.getMigrationsTableSql());
      expect(cmd['_vania_migration'], 'createCollection');
      expect(cmd['name'], '_migrations');
    });
  });
}
