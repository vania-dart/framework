// ignore_for_file: non_constant_identifier_names

import 'impl/legacy_query_builder.dart';
import 'query_builder/_query_builder_impl.dart' show QueryBuilderImpl;

/// Top-level entry point: `DB.table('users').where(...).get()`.
QueryBuilder get DB => QueryBuilderImpl();
