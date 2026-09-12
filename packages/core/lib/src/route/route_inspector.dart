import 'dart:convert';
import 'dart:io';

import 'router.dart';

/// Environment variable that makes the server print its routing table and
/// exit instead of binding a port.
const String routeDumpEnvVar = 'VANIA_DUMP_ROUTES';

/// Marks the start of the machine-readable payload, so the CLI can find
/// it in output that also contains the app's own boot logging.
const String routeDumpMarker = '__VANIA_ROUTES__';

/// Serialises the registered routes as JSON.
String describeRoutes() {
  final routes = Router().routes.map((route) {
    final prefix = route.prefix;
    final path = route.path.startsWith('/') ? route.path : '/${route.path}';
    final full = (prefix == null || prefix.isEmpty)
        ? path
        : '/${prefix.replaceAll(RegExp(r'^/+|/+$'), '')}$path';

    return <String, dynamic>{
      'method': route.method.toUpperCase(),
      'uri': full.replaceAll(RegExp('/+'), '/'),
      'name': route.name,
      'domain': route.domain,
      'middleware': route.preMiddleware
          .map((m) => m.runtimeType.toString())
          .toList(),
      'constraints': route.regex,
    };
  }).toList();

  return jsonEncode(routes);
}

/// Prints the routing table and exits when [routeDumpEnvVar] is set.
void dumpRoutesIfRequested() {
  if (Platform.environment[routeDumpEnvVar] != '1') return;

  stdout
    ..writeln(routeDumpMarker)
    ..writeln(describeRoutes());
  exit(0);
}
