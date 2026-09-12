import 'package:vania/foundation.dart' show InvalidArgumentException;

/// Validates SQL identifiers that the builder interpolates directly into
/// the statement.
///
/// Values are safe — they go through bound parameters. Identifiers cannot:
/// there is no placeholder syntax for a column or table name, so
/// `orderBy(column)` had to concatenate whatever it was handed straight
/// into the SQL text. That made this very common ORM-style line an
/// injection point:
///
/// ```dart
/// User().query().orderBy(request.input('sort'), request.input('dir'))
/// ```
///
/// With `sort = "id) --"` or `dir = "ASC, (SELECT …)"` the attacker owns
/// the tail of the query.
///
/// The grammar accepted here is deliberately narrow: bare identifiers,
/// optionally qualified (`table.column`, `schema.table.column`) and
/// optionally wildcarded (`*`, `table.*`). Anything else — function
/// calls, arithmetic, subqueries, comments, quotes — is rejected with a
/// message pointing at the matching `…Raw` method, which is where an
/// intentional SQL fragment belongs.
///
/// This mirrors the operator whitelist that already guards `where`
/// clauses; identifiers were the half of the problem that was left open.
class SqlIdentifierGuard {
  const SqlIdentifierGuard._();

  /// A single unqualified identifier: `users`, `created_at`, `_tmp`.
  static final RegExp _bareIdentifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_$]*$');

  static const int _maxIdentifierLength = 63;

  /// Validates a column reference and returns it unchanged.
  ///
  /// Accepts `col`, `tbl.col`, `schema.tbl.col`, `*`, `tbl.*`.
  static String column(String reference, {String context = 'Column'}) {
    final ref = reference.trim();

    if (ref.isEmpty) {
      throw InvalidArgumentException('$context cannot be empty.');
    }

    if (ref == '*') return reference;

    final parts = ref.split('.');
    if (parts.length > 3) {
      throw InvalidArgumentException(
        '$context "$reference" has too many qualifiers. '
        'Expected at most schema.table.column.',
      );
    }

    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];

      // Only the final segment may be a wildcard: `users.*` is fine,
      // `*.id` is not.
      if (part == '*') {
        if (i == parts.length - 1) continue;
        throw InvalidArgumentException(
          '$context "$reference" may only use * as the last segment.',
        );
      }

      if (part.length > _maxIdentifierLength) {
        throw InvalidArgumentException(
          '$context "$reference" has a segment longer than '
          '$_maxIdentifierLength characters.',
        );
      }

      if (!_bareIdentifier.hasMatch(part)) {
        throw InvalidArgumentException(
          'Invalid ${context.toLowerCase()} reference: "$reference". '
          'Only plain identifiers are allowed here (letters, digits and '
          'underscores, optionally qualified as table.column). '
          'For SQL expressions use the matching Raw method — e.g. '
          'orderByRaw(), groupByRaw(), havingRaw() or selectRaw() — so the '
          'intent to emit raw SQL is explicit.',
        );
      }
    }

    return reference;
  }

  /// Validates every reference in [references].
  static List<String> columns(
    List<String> references, {
    String context = 'Column',
  }) {
    for (final reference in references) {
      column(reference, context: context);
    }
    return references;
  }

  /// Validates a sort direction and returns it normalised to upper case.
  ///
  /// Only `ASC` and `DESC` are accepted; the direction is interpolated
  /// into the statement, so it cannot be free text.
  static String direction(String direction) {
    final normalised = direction.trim().toUpperCase();
    if (normalised != 'ASC' && normalised != 'DESC') {
      throw InvalidArgumentException(
        'Invalid sort direction: "$direction". Expected ASC or DESC.',
      );
    }
    return normalised;
  }

  /// Validates a table reference, which may carry an alias.
  static String table(String name) => column(name, context: 'Table');

  /// Comparison operators the builder is allowed to interpolate.
  ///
  /// Shared by WHERE and HAVING, which build comparisons the same way.
  static const Set<String> _validOperators = {
    '=',
    '<>',
    '!=',
    '<',
    '>',
    '<=',
    '>=',
    'LIKE',
    'NOT LIKE',
    'ILIKE', // PostgreSQL case-insensitive LIKE
    'NOT ILIKE',
    'REGEXP',
    'NOT REGEXP',
    'RLIKE', // MySQL alias for REGEXP
    'SIMILAR TO', // PostgreSQL
  };

  /// Validates a comparison operator.
  static void operator(String op) {
    if (!_validOperators.contains(op.toUpperCase())) {
      throw InvalidArgumentException(
        'Invalid SQL operator: "$op". '
        'Allowed operators: ${_validOperators.join(", ")}',
      );
    }
  }

  /// Validates an alias (`AS x`) — always a single bare identifier.
  static String alias(String name) {
    final trimmed = name.trim();
    if (!_bareIdentifier.hasMatch(trimmed) ||
        trimmed.length > _maxIdentifierLength) {
      throw InvalidArgumentException(
        'Invalid alias: "$name". Expected a plain identifier.',
      );
    }
    return name;
  }
}
