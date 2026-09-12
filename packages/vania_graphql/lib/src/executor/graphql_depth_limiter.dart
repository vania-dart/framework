import 'package:graphql_parser2/graphql_parser2.dart';

/// Computes the nesting depth of a GraphQL document so absurdly nested
/// queries can be rejected before execution.
///
/// GraphQL's cost is not bounded by request size: a schema with any
/// cycle in it (`user → posts → author → posts → …`, which is the normal
/// shape of a relational schema) lets a few hundred bytes expand into an
/// unbounded number of resolver calls and database round-trips. A length
/// cap does not help — the payload stays tiny. Depth is the cheap,
/// standard guard.
///
/// Fragments are resolved by name so a query cannot smuggle depth past
/// the limit by hiding it in a fragment. Cyclic fragment spreads — which
/// are invalid GraphQL, but arrive from attackers anyway — are cut off by
/// tracking the spreads currently being expanded, so this never recurses
/// forever.
class GraphQLDepthLimiter {
  const GraphQLDepthLimiter._();

  /// Returns the maximum selection depth of [query], or `null` when the
  /// document cannot be parsed.
  ///
  /// A parse failure is not this class's problem to report: the executor
  /// runs the real parser immediately afterwards and produces a proper
  /// GraphQL error. Returning null means "no opinion".
  static int? depthOf(String query) {
    final DocumentContext document;
    try {
      document = Parser(scan(query)).parseDocument();
    } catch (_) {
      return null;
    }

    final fragments = <String, FragmentDefinitionContext>{
      for (final def in document.definitions)
        if (def is FragmentDefinitionContext && def.name != null)
          def.name!: def,
    };

    var max = 0;
    for (final def in document.definitions) {
      if (def is OperationDefinitionContext) {
        final d = _selectionSetDepth(def.selectionSet, fragments, <String>{});
        if (d > max) max = d;
      }
    }
    return max;
  }

  static int _selectionSetDepth(
    SelectionSetContext? selectionSet,
    Map<String, FragmentDefinitionContext> fragments,
    Set<String> expanding,
  ) {
    if (selectionSet == null) return 0;

    var deepest = 0;
    for (final selection in selectionSet.selections) {
      final d = _selectionDepth(selection, fragments, expanding);
      if (d > deepest) deepest = d;
    }
    return deepest;
  }

  static int _selectionDepth(
    SelectionContext selection,
    Map<String, FragmentDefinitionContext> fragments,
    Set<String> expanding,
  ) {
    final field = selection.field;
    if (field != null) {
      // A leaf field is depth 1; a field with children is 1 + its deepest
      // child.
      return 1 + _selectionSetDepth(field.selectionSet, fragments, expanding);
    }

    final inline = selection.inlineFragment;
    if (inline != null) {
      // Inline fragments are a type condition, not a level of nesting.
      return _selectionSetDepth(inline.selectionSet, fragments, expanding);
    }

    final spread = selection.fragmentSpread;
    if (spread != null) {
      final name = spread.name;
      if (name == null) return 0;
      // Already expanding this fragment => cycle. Stop rather than
      // recurse; the real parser will reject the document anyway.
      if (expanding.contains(name)) return 0;
      final fragment = fragments[name];
      if (fragment == null) return 0;

      return _selectionSetDepth(fragment.selectionSet, fragments, {
        ...expanding,
        name,
      });
    }

    return 0;
  }
}
