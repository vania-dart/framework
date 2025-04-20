// ignore_for_file: non_constant_identifier_names

import '../contract/database/query_builder/query_builder.dart';
import 'query_builder/_query_builder_impl.dart' show QueryBuilderImpl;

QueryBuilder get DB => QueryBuilderImpl();
