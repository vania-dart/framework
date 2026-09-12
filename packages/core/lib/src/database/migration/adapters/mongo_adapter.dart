import 'dart:convert';

import '../../enum/column_index.dart';
import '../blueprint/column_blueprint.dart';
import '../blueprint/table_blueprint.dart';
import '../contracts/database_adapter_interface.dart';

class MongoAdapter implements DatabaseAdapterInterface {
  @override
  String get driverName => 'mongodb';

  @override
  String get migrationsTable => '_migrations';

  @override
  String adaptQuery(String query) => query;

  @override
  String getMigrationsTableSql() {
    return jsonEncode({
      '_vania_migration': 'createCollection',
      'name': migrationsTable,
    });
  }

  @override
  bool supports(String driver) {
    final d = driver.toLowerCase();
    return d == 'mongodb' || d == 'mongo';
  }

  @override
  String escapeIdentifier(String identifier) => identifier;

  @override
  String formatValue(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return '"${value.replaceAll('"', '\\"')}"';
    if (value is num) return value.toString();
    if (value is bool) return value.toString();
    return '"$value"';
  }

  @override
  List<String> renderCreateTable(
    TableBlueprint blueprint, {
    bool ifNotExists = false,
  }) {
    final statements = <String>[];

    final required = <String>[];
    final properties = <String, dynamic>{};

    for (final col in blueprint.columns) {
      properties[col.name] = _mongoBsonSchema(col);
      if (!col.nullable) required.add(col.name);
    }

    final validator = <String, dynamic>{
      '\$jsonSchema': {
        'bsonType': 'object',
        if (required.isNotEmpty) 'required': required,
        'properties': properties,
      },
    };

    statements.add(
      jsonEncode({
        '_vania_migration': 'createCollection',
        'name': blueprint.tableName,
        'options': {'validator': validator},
      }),
    );

    for (final idx in blueprint.indexes) {
      statements.add(
        jsonEncode({
          '_vania_migration': 'createIndex',
          'collection': blueprint.tableName,
          'keys': {for (final c in idx.columns) c: 1},
          'options': {
            'name': idx.name,
            if (idx.type == ColumnIndex.unique) 'unique': true,
          },
        }),
      );
    }

    for (final uc in blueprint.uniqueConstraints) {
      statements.add(
        jsonEncode({
          '_vania_migration': 'createIndex',
          'collection': blueprint.tableName,
          'keys': {for (final c in uc.columns) c: 1},
          'options': {'name': uc.name, 'unique': true},
        }),
      );
    }

    for (final fk in blueprint.foreignKeys) {
      statements.add(
        jsonEncode({
          '_vania_migration': 'createIndex',
          'collection': blueprint.tableName,
          'keys': {fk.columnName: 1},
          'options': {'name': 'idx_fk_${fk.columnName}'},
        }),
      );
    }

    return statements;
  }

  Map<String, dynamic> _mongoBsonSchema(ColumnBlueprint col) {
    final schema = <String, dynamic>{'bsonType': _mongoBsonType(col.type)};
    if (col.comment != null) schema['description'] = col.comment;
    if (col.enumValues != null && col.enumValues!.isNotEmpty) {
      schema['enum'] = col.enumValues;
    }
    return schema;
  }

  String _mongoBsonType(ColumnType type) {
    switch (type) {
      case ColumnType.bigInt:
      case ColumnType.integer:
      case ColumnType.tinyInt:
      case ColumnType.smallInt:
      case ColumnType.mediumInt:
      case ColumnType.bit:
      case ColumnType.year:
        return 'int';
      case ColumnType.float:
      case ColumnType.double:
      case ColumnType.decimal:
        return 'double';
      case ColumnType.varchar:
      case ColumnType.char:
      case ColumnType.text:
      case ColumnType.tinyText:
      case ColumnType.mediumText:
      case ColumnType.longText:
      case ColumnType.uuid:
      case ColumnType.enumType:
      case ColumnType.setType:
        return 'string';
      case ColumnType.json:
        return 'object';
      case ColumnType.binary:
      case ColumnType.varBinary:
      case ColumnType.blob:
      case ColumnType.tinyBlob:
      case ColumnType.mediumBlob:
      case ColumnType.longBlob:
        return 'binData';
      case ColumnType.date:
      case ColumnType.time:
      case ColumnType.dateTime:
      case ColumnType.timestamp:
        return 'date';
      case ColumnType.boolean:
        return 'bool';
      case ColumnType.point:
      case ColumnType.lineString:
      case ColumnType.polygon:
      case ColumnType.geometry:
      case ColumnType.multiPoint:
      case ColumnType.multiLineString:
      case ColumnType.multiPolygon:
      case ColumnType.geometryCollection:
        return 'object';
    }
  }

  @override
  List<String> renderAlterAddColumns(
    String table,
    TableBlueprint changes, {
    String afterColumn = '',
    String beforeColumn = '',
  }) {
    final statements = <String>[];

    if (changes.columns.isNotEmpty) {
      final required = <String>[];
      final properties = <String, dynamic>{};
      for (final col in changes.columns) {
        properties[col.name] = _mongoBsonSchema(col);
        if (!col.nullable) required.add(col.name);
      }

      statements.add(
        jsonEncode({
          '_vania_migration': 'addValidatorFields',
          'collection': table,
          'properties': properties,
          if (required.isNotEmpty) 'required': required,
        }),
      );
    }

    for (final idx in changes.indexes) {
      statements.add(
        jsonEncode({
          '_vania_migration': 'createIndex',
          'collection': table,
          'keys': {for (final c in idx.columns) c: 1},
          'options': {
            'name': idx.name,
            if (idx.type == ColumnIndex.unique) 'unique': true,
          },
        }),
      );
    }

    return statements;
  }

  /// Collections carry none of these SQL table options.
  @override
  List<String> renderTableOptions(
    String tableName, {
    String? engine,
    String? charset,
    String? collation,
    String? comment,
    int? autoIncrement,
  }) => const [];

  @override
  List<String> renderDropTable(String tableName, {bool ifExists = false}) {
    return [
      jsonEncode({'_vania_migration': 'dropCollection', 'name': tableName}),
    ];
  }

  @override
  List<String> renderDropColumn(String tableName, String columnName) {
    return [
      jsonEncode({
        '_vania_migration': 'removeField',
        'collection': tableName,
        'field': columnName,
      }),
    ];
  }

  @override
  List<String> renderRenameColumn(
    String tableName,
    String oldName,
    String newName,
  ) {
    return [
      jsonEncode({
        '_vania_migration': 'renameField',
        'collection': tableName,
        'oldName': oldName,
        'newName': newName,
      }),
    ];
  }

  @override
  List<String> renderRenameTable(String oldName, String newName) {
    return [
      jsonEncode({
        '_vania_migration': 'renameCollection',
        'oldName': oldName,
        'newName': newName,
      }),
    ];
  }

  @override
  List<String> renderAddIndex(String tableName, IndexBlueprint index) {
    return [
      jsonEncode({
        '_vania_migration': 'createIndex',
        'collection': tableName,
        'keys': {for (final c in index.columns) c: 1},
        'options': {
          'name': index.name,
          if (index.type == ColumnIndex.unique) 'unique': true,
        },
      }),
    ];
  }

  @override
  List<String> renderDropIndex(String tableName, String indexName) {
    return [
      jsonEncode({
        '_vania_migration': 'dropIndex',
        'collection': tableName,
        'indexName': indexName,
      }),
    ];
  }
}
