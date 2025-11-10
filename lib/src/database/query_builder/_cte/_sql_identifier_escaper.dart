import 'package:vania/src/exception/invalid_argument_exception.dart';

class SqlIdentifierEscaper {
  static const Set<String> _reservedWords = {
    'select',
    'from',
    'where',
    'insert',
    'update',
    'delete',
    'create',
    'drop',
    'alter',
    'table',
    'view',
    'index',
    'database',
    'schema',
    'order',
    'group',
    'having',
    'limit',
    'offset',
    'join',
    'inner',
    'left',
    'right',
    'full',
    'outer',
    'cross',
    'on',
    'using',
    'as',
    'in',
    'exists',
    'count',
    'sum',
    'avg',
    'min',
    'max',
    'case',
    'when',
    'then',
    'else',
    'end',
    'and',
    'or',
    'like',
    'between',
    'true',
    'false',
    'is',
    'begin',
    'commit',
    'rollback',
    'with',
    'recursive',
    'union',
    'all',
    'distinct',
  };

  static bool needsEscaping(String identifier) {
    if (identifier.isEmpty) return false;

    if (_hasInvalidPattern(identifier)) return true;

    if (_reservedWords.contains(identifier.toLowerCase())) return true;

    if (_looksLikeSqlKeyword(identifier)) return true;

    return false;
  }

  static bool _hasInvalidPattern(String identifier) {
    if (RegExp(r'^\d').hasMatch(identifier)) return true;

    if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(identifier)) return true;

    return false;
  }

  static bool _looksLikeSqlKeyword(String identifier) {
    final lower = identifier.toLowerCase();

    if (identifier.length <= 10 &&
        identifier == identifier.toUpperCase() &&
        identifier.isNotEmpty &&
        RegExp(r'^[A-Z]+$').hasMatch(identifier)) {
      if (RegExp(
        r'^(ID|URL|API|UUID|JSON|XML|HTML|CSS|JS)$',
      ).hasMatch(identifier)) {
        return false;
      }
      if (RegExp(r'(ID|NAME|CODE|TYPE|FLAG|DATA)$').hasMatch(identifier)) {
        return false;
      }
      return true;
    }

    if (RegExp(
      r'^(select|insert|update|delete|create|drop|alter|grant|revoke)',
    ).hasMatch(lower)) {
      return true;
    }

    if (RegExp(
      r'^(count|sum|avg|min|max|concat|substr|trim|upper|lower)$',
    ).hasMatch(lower)) {
      return true;
    }

    if (RegExp(
      r'^(now|today|current_date|current_time|current_timestamp)$',
    ).hasMatch(lower)) {
      return true;
    }

    if (RegExp(r'^(date_|time_)').hasMatch(lower) &&
        !RegExp(r'_(at|on|by|for|from|to)$').hasMatch(lower)) {
      return true;
    }

    return false;
  }

  static void validateIdentifier(
    String identifier, {
    String context = 'Identifier',
  }) {
    if (identifier.trim().isEmpty) {
      throw InvalidArgumentException('$context cannot be empty or whitespace');
    }
    if (identifier.length > 63) {
      throw InvalidArgumentException(
        '$context name is too long (max 63 characters): ${identifier.length}',
      );
    }
    if (identifier.contains('0')) {
      throw InvalidArgumentException('$context cannot contain null character');
    }
  }
}
