import 'dart:async';

import '../contracts/database_adapter_interface.dart';
import '../migration_connection.dart';

class TableDefinition implements Future<void> {
  final String _tableName;
  final Future<void> Function() _createFunction;
  final MigrationConnection? _connection;
  final DatabaseAdapterInterface? _adapter;

  String? _engine;
  String? _comment;
  String? _charset;
  String? _collation;
  int? _autoIncrement;

  TableDefinition(
    this._tableName,
    this._createFunction, {
    MigrationConnection? connection,
    DatabaseAdapterInterface? adapter,
  })  : _connection = connection,
        _adapter = adapter;

  TableDefinition engine(String engine) {
    _engine = engine;
    return this;
  }

  TableDefinition comment(String comment) {
    _comment = comment;
    return this;
  }

  TableDefinition charset(String charset) {
    _charset = charset;
    return this;
  }

  TableDefinition collate(String collation) {
    _collation = collation;
    return this;
  }

  TableDefinition autoIncrement(int startValue) {
    _autoIncrement = startValue;
    return this;
  }

  Future<void> _getExecutionFuture() async {
    await _createFunction();
    await _applyTableOptions();
  }

  @override
  Future<R> then<R>(FutureOr<R> Function(void value) onValue,
      {Function? onError}) {
    return _getExecutionFuture().then(onValue, onError: onError);
  }

  @override
  Future<void> catchError(Function onError,
      {bool Function(Object error)? test}) {
    return _getExecutionFuture().catchError(onError, test: test);
  }

  @override
  Future<void> whenComplete(FutureOr<void> Function() action) {
    return _getExecutionFuture().whenComplete(action);
  }

  @override
  Future<void> timeout(
    Duration timeLimit, {
    FutureOr<void> Function()? onTimeout,
  }) {
    return _getExecutionFuture().timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Stream<void> asStream() {
    return _getExecutionFuture().asStream();
  }

  Future<void> _applyTableOptions() async {
    if (_engine == null &&
        _comment == null &&
        _charset == null &&
        _collation == null &&
        _autoIncrement == null) {
      return; // No options to apply
    }

    final options = <String>[];

    if (_engine != null) {
      options.add('ENGINE=$_engine');
    }

    if (_charset != null) {
      options.add('DEFAULT CHARSET=$_charset');
    }

    if (_collation != null) {
      options.add('COLLATE=$_collation');
    }

    if (_comment != null) {
      options.add("COMMENT='$_comment'");
    }

    if (_autoIncrement != null) {
      options.add('AUTO_INCREMENT=$_autoIncrement');
    }

    if (options.isNotEmpty && _connection?.connection != null) {
      String alterSql = 'ALTER TABLE `$_tableName` ${options.join(', ')}';

      if (_adapter != null) {
        alterSql = _adapter.adaptQuery(alterSql);
      }

      await _connection!.connection!.execute(alterSql);
    }
  }
}
