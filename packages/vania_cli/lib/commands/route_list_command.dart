import 'dart:convert';
import 'dart:io';

import '../common/console.dart';
import 'command.dart';

class RouteListCommand extends Command {
  @override
  String get name => 'route:list';

  @override
  String get description => 'List the registered application routes';

  @override
  String get usage =>
      '[--method <verb>] [--path <text>] [--name <text>] [--json]';

  @override
  Future<int> execute(List<String> arguments) async {
    final options = _RouteListOptions.parse(arguments);
    if (options == null) return ExitCode.usage;

    final entrypoint = File('${workingDirectory.path}/bin/server.dart');
    if (!entrypoint.existsSync()) {
      Console.error('bin/server.dart does not exist.');
      return ExitCode.noInput;
    }

    final result = await Process.run(
      'dart',
      ['run', 'bin/server.dart'],
      workingDirectory: workingDirectory.path,
      environment: const {'VANIA_DUMP_ROUTES': '1'},
    );
    final routes = RouteListParser.parse(result.stdout.toString());
    if (routes == null) {
      Console.error('Could not read the route table from the application.');
      final details = result.stderr.toString().trim();
      if (details.isNotEmpty) Console.line(Console.dim(details));
      return ExitCode.failure;
    }

    final matching =
        routes.where(options.filter.matches).toList()..sort((left, right) {
          final pathOrder = left.uri.compareTo(right.uri);
          return pathOrder == 0
              ? left.method.compareTo(right.method)
              : pathOrder;
        });

    if (options.json) {
      Console.line(
        const JsonEncoder.withIndent(
          '  ',
        ).convert(matching.map((route) => route.toJson()).toList()),
      );
      return ExitCode.success;
    }
    if (matching.isEmpty) {
      Console.info(
        routes.isEmpty
            ? 'No routes are registered.'
            : 'No routes match the filters.',
      );
      return ExitCode.success;
    }

    Console.table(
      const ['METHOD', 'URI', 'NAME', 'MIDDLEWARE'],
      matching
          .map(
            (route) => [
              route.method,
              route.uri,
              route.name ?? '',
              route.middleware.join(', '),
            ],
          )
          .toList(),
      colorize: (column, value) {
        if (column == 0) return _colorMethod(value.trim(), value);
        if (column >= 2) return Console.dim(value);
        return value;
      },
    );
    Console.line();
    Console.info(Console.dim('${matching.length} route(s)'));
    return ExitCode.success;
  }

  static String _colorMethod(String method, String value) {
    return switch (method) {
      'GET' || 'HEAD' => Console.blue(value),
      'POST' => Console.green(value),
      'PUT' || 'PATCH' => Console.yellow(value),
      'DELETE' => Console.red(value),
      _ => Console.magenta(value),
    };
  }
}

class RouteListParser {
  const RouteListParser._();

  static const String marker = '__VANIA_ROUTES__';

  static List<RouteDescription>? parse(String output) {
    final markerIndex = output.indexOf(marker);
    if (markerIndex < 0) return null;

    try {
      final decoded = jsonDecode(
        output.substring(markerIndex + marker.length).trim(),
      );
      if (decoded is! List) return null;
      return decoded
          .map(RouteDescription.fromJson)
          .whereType<RouteDescription>()
          .toList();
    } on FormatException {
      return null;
    }
  }
}

class RouteDescription {
  const RouteDescription({
    required this.method,
    required this.uri,
    required this.middleware,
    this.name,
  });

  factory RouteDescription.fromJson(dynamic value) {
    if (value is! Map) {
      throw const FormatException('A route must be an object.');
    }
    final method = value['method'];
    final uri = value['uri'];
    final middleware = value['middleware'];
    if (method is! String || uri is! String || middleware is! List) {
      throw const FormatException('A route has invalid fields.');
    }
    return RouteDescription(
      method: method.toUpperCase(),
      uri: uri,
      name: value['name'] is String ? value['name'] as String : null,
      middleware: middleware.whereType<String>().toList(),
    );
  }

  final String method;
  final String uri;
  final String? name;
  final List<String> middleware;

  Map<String, Object?> toJson() => {
    'method': method,
    'uri': uri,
    'name': name,
    'middleware': middleware,
  };
}

class RouteFilter {
  RouteFilter({String? method, this.path, this.name})
    : method = method?.toUpperCase();

  final String? method;
  final String? path;
  final String? name;

  bool matches(RouteDescription route) {
    if (method != null && route.method != method) return false;
    if (path != null && !route.uri.contains(path!)) return false;
    if (name != null && !(route.name ?? '').contains(name!)) return false;
    return true;
  }
}

class _RouteListOptions {
  const _RouteListOptions({required this.filter, required this.json});

  final RouteFilter filter;
  final bool json;

  static _RouteListOptions? parse(List<String> arguments) {
    String? method;
    String? path;
    String? name;
    var json = false;

    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (argument == '--json') {
        json = true;
        continue;
      }
      if (argument != '--method' &&
          argument != '--path' &&
          argument != '--name') {
        Console.error('Unknown option: $argument');
        return null;
      }
      if (index + 1 >= arguments.length) {
        Console.error('$argument needs a value.');
        return null;
      }
      final value = arguments[++index];
      if (argument == '--method') method = value;
      if (argument == '--path') path = value;
      if (argument == '--name') name = value;
    }

    return _RouteListOptions(
      filter: RouteFilter(method: method, path: path, name: name),
      json: json,
    );
  }
}
