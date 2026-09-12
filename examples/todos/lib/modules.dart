import 'package:vania/route.dart';
import 'package:todos/features/todos/todos_route.dart';

/// Every feature module the app is composed of. To add a feature, drop a
/// folder under `lib/features/` and add its `Route` here — nothing else
/// in the app needs to change.
final List<Route> modules = [
  TodosRoute(),
];
