import 'package:test/test.dart';
import 'package:vania/database.dart';

void main() {
  group('ColumnBlueprint', () {
    test('creates with required fields', () {
      const col = ColumnBlueprint(name: 'id', type: ColumnType.bigInt);
      expect(col.name, 'id');
      expect(col.type, ColumnType.bigInt);
      expect(col.nullable, true);
      expect(col.autoIncrement, false);
      expect(col.unique, false);
    });

    test('creates with all fields', () {
      const col = ColumnBlueprint(
        name: 'email',
        type: ColumnType.varchar,
        nullable: false,
        length: 255,
        unique: true,
        defaultValue: 'test@example.com',
        comment: 'User email',
      );
      expect(col.name, 'email');
      expect(col.type, ColumnType.varchar);
      expect(col.nullable, false);
      expect(col.length, 255);
      expect(col.unique, true);
      expect(col.defaultValue, 'test@example.com');
      expect(col.comment, 'User email');
    });

    test('enum values are stored', () {
      const col = ColumnBlueprint(
        name: 'status',
        type: ColumnType.enumType,
        enumValues: ['active', 'inactive', 'pending'],
      );
      expect(col.enumValues, ['active', 'inactive', 'pending']);
    });
  });

  group('TableBlueprint', () {
    test('creates with columns and primary key', () {
      const bp = TableBlueprint(
        tableName: 'users',
        columns: [
          ColumnBlueprint(
            name: 'id',
            type: ColumnType.bigInt,
            autoIncrement: true,
            nullable: false,
          ),
          ColumnBlueprint(name: 'name', type: ColumnType.varchar, length: 255),
        ],
        primaryKey: 'id',
      );
      expect(bp.tableName, 'users');
      expect(bp.columns.length, 2);
      expect(bp.primaryKey, 'id');
    });

    test('stores indexes', () {
      const bp = TableBlueprint(
        tableName: 'posts',
        indexes: [
          IndexBlueprint(name: 'idx_user_id', columns: ['user_id']),
        ],
      );
      expect(bp.indexes.length, 1);
      expect(bp.indexes.first.name, 'idx_user_id');
    });

    test('stores foreign keys', () {
      const bp = TableBlueprint(
        tableName: 'posts',
        foreignKeys: [
          ForeignKeyBlueprint(
            columnName: 'user_id',
            referencesTable: 'users',
            referencesColumn: 'id',
            onDelete: 'CASCADE',
          ),
        ],
      );
      expect(bp.foreignKeys.length, 1);
      expect(bp.foreignKeys.first.referencesTable, 'users');
    });

    test('stores unique constraints', () {
      const bp = TableBlueprint(
        tableName: 'users',
        uniqueConstraints: [
          UniqueConstraintBlueprint(
            name: 'uniq_email_org',
            columns: ['email', 'org_id'],
          ),
        ],
      );
      expect(bp.uniqueConstraints.length, 1);
      expect(bp.uniqueConstraints.first.columns, ['email', 'org_id']);
    });
  });

  group('Schema → TableBlueprint', () {
    test('schema.id() creates auto-increment primary key', () {
      final schema = Schema();
      schema.setTableName('users');
      schema.id();
      final bp = schema.toBlueprint();

      expect(bp.tableName, 'users');
      expect(bp.primaryKey, 'id');
      expect(bp.columns.length, 1);
      expect(bp.columns.first.name, 'id');
      expect(bp.columns.first.type, ColumnType.bigInt);
      expect(bp.columns.first.autoIncrement, true);
      expect(bp.columns.first.unsigned, true);
      expect(bp.columns.first.nullable, false);
    });

    test('schema.string() creates varchar(255)', () {
      final schema = Schema();
      schema.setTableName('users');
      schema.string('name');
      final bp = schema.toBlueprint();

      expect(bp.columns.first.type, ColumnType.varchar);
      expect(bp.columns.first.length, 255);
    });

    test('schema.timeStamps() creates created_at and updated_at', () {
      final schema = Schema();
      schema.setTableName('users');
      schema.timeStamps();
      final bp = schema.toBlueprint();

      expect(bp.columns.length, 2);
      expect(bp.columns[0].name, 'created_at');
      expect(bp.columns[0].type, ColumnType.timestamp);
      expect(bp.columns[0].nullable, true);
      expect(bp.columns[1].name, 'updated_at');
    });

    test('schema.uuid() creates uuid column', () {
      final schema = Schema();
      schema.setTableName('items');
      schema.uuid('external_id');
      final bp = schema.toBlueprint();

      expect(bp.columns.first.type, ColumnType.uuid);
    });

    test('schema.boolean() creates boolean column', () {
      final schema = Schema();
      schema.setTableName('items');
      schema.boolean('is_active');
      final bp = schema.toBlueprint();

      expect(bp.columns.first.type, ColumnType.boolean);
    });

    test('column definition fluent API works', () {
      final schema = Schema();
      schema.setTableName('users');
      schema.string('email').notNull().unique().defaultTo('a@b.com');
      final bp = schema.toBlueprint();

      final col = bp.columns.first;
      expect(col.nullable, false);
      expect(col.unique, true);
      expect(col.defaultValue, 'a@b.com');
    });

    test('foreign key stored in blueprint', () {
      final schema = Schema();
      schema.setTableName('posts');
      schema.bigInt('user_id').notNull().foreignKey('users', 'id');
      final bp = schema.toBlueprint();

      expect(bp.foreignKeys.length, 1);
      expect(bp.foreignKeys.first.columnName, 'user_id');
      expect(bp.foreignKeys.first.referencesTable, 'users');
    });

    test('index stored in blueprint', () {
      final schema = Schema();
      schema.setTableName('logs');
      schema.string('level').index('idx_level');
      final bp = schema.toBlueprint();

      expect(bp.indexes.length, 1);
      expect(bp.indexes.first.name, 'idx_level');
      expect(bp.indexes.first.columns, ['level']);
    });

    test('composite unique constraint', () {
      final schema = Schema();
      schema.setTableName('subscriptions');
      schema.bigInt('user_id').unique('uniq_user_plan');
      schema.bigInt('plan_id').unique('uniq_user_plan');
      final bp = schema.toBlueprint();

      expect(bp.uniqueConstraints.length, 1);
      expect(bp.uniqueConstraints.first.name, 'uniq_user_plan');
      expect(bp.uniqueConstraints.first.columns, ['user_id', 'plan_id']);
    });

    test('reset clears all state', () {
      final schema = Schema();
      schema.setTableName('users');
      schema.id();
      schema.string('name');
      schema.toBlueprint();

      schema.reset();
      schema.setTableName('posts');
      schema.id();
      final bp = schema.toBlueprint();

      expect(bp.tableName, 'posts');
      expect(bp.columns.length, 1);
    });

    test('enum type stores values', () {
      final schema = Schema();
      schema.setTableName('tickets');
      schema.enumType('status', ['open', 'closed', 'pending']);
      final bp = schema.toBlueprint();

      expect(bp.columns.first.type, ColumnType.enumType);
      expect(bp.columns.first.enumValues, ['open', 'closed', 'pending']);
    });

    test('decimal with precision and scale', () {
      final schema = Schema();
      schema.setTableName('products');
      schema.decimal('price', precision: 10, scale: 2);
      final bp = schema.toBlueprint();

      expect(bp.columns.first.type, ColumnType.decimal);
      expect(bp.columns.first.precision, 10);
      expect(bp.columns.first.scale, 2);
    });
  });
}
