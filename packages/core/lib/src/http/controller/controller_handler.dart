import 'package:vania/src/http/request/request.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/route/route_data.dart';

class ControllerHandler {
  /// Converts a route parameter from its URL text to the value passed to
  /// the controller.
  ///
  /// `42` becomes an `int`, `4.2` a `double`, `true`/`false` a `bool`;
  /// anything else stays a `String`.
  ///
  /// Numeric-looking values whose text form carries meaning are left as
  /// strings: a leading zero (`007`, postal codes, phone numbers), a
  /// leading `+`, or exponent notation (`1e5`). Converting those loses
  /// information the caller cannot recover.
  dynamic _getParamValue(String param) {
    if (_isPlainInteger(param)) {
      final asInt = int.tryParse(param);
      if (asInt != null) return asInt;
    }

    if (_isPlainDecimal(param)) {
      final asDouble = double.tryParse(param);
      if (asDouble != null) return asDouble;
    }

    final lower = param.toLowerCase();
    if (lower == 'true') return true;
    if (lower == 'false') return false;

    return param;
  }

  /// True for `0`, `7`, `-7` — but not `007`, `+7` or `1e5`.
  static bool _isPlainInteger(String v) {
    final digits = v.startsWith('-') ? v.substring(1) : v;
    if (digits.isEmpty) return false;
    for (var i = 0; i < digits.length; i++) {
      final c = digits.codeUnitAt(i);
      if (c < 0x30 || c > 0x39) return false;
    }
    return digits.length == 1 || digits.codeUnitAt(0) != 0x30;
  }

  /// True for `4.2`, `-0.5` — but not `04.2` or `4.2e1`.
  static bool _isPlainDecimal(String v) {
    final dot = v.indexOf('.');
    if (dot == -1 || v.indexOf('.', dot + 1) != -1) return false;
    final whole = v.substring(0, dot);
    final fraction = v.substring(dot + 1);
    if (fraction.isEmpty) return false;
    for (var i = 0; i < fraction.length; i++) {
      final c = fraction.codeUnitAt(i);
      if (c < 0x30 || c > 0x39) return false;
    }
    return _isPlainInteger(whole) || whole == '0' || whole == '-0';
  }

  /// Calls the route's action and returns its [Response], unwritten.
  ///
  /// Writing it is left to the request handler, once the middleware chain
  /// has finished, so a middleware wrapping the chain can still add to
  /// the response after `next()` returns. An error is not handled here
  /// either: it travels back out through the middleware, which may want
  /// to see it, to the one place that turns errors into responses.
  Future<Response> create({
    required RouteData route,
    required Request request,
  }) async {
    final positionalArguments = <dynamic>[if (route.hasRequest) request];
    final declared = route.paramTypes;
    route.params?.forEach((name, value) {
      // A `where*` type was already checked and applied when the route
      // matched; only undeclared params are inferred from their text.
      positionalArguments.add(
        declared != null && declared.containsKey(name)
            ? value
            : _getParamValue(value.toString()),
      );
    });
    return await _invoke(route.action, positionalArguments);
  }
}

/// Calls [action] with [args].
///
/// A direct call for the arities routes use in practice: `Function.apply`
/// costs some thirty times as much and runs on every request.
dynamic _invoke(Function action, List<dynamic> args) {
  final dynamic f = action;
  return switch (args.length) {
    0 => f(),
    1 => f(args[0]),
    2 => f(args[0], args[1]),
    3 => f(args[0], args[1], args[2]),
    4 => f(args[0], args[1], args[2], args[3]),
    _ => Function.apply(action, args),
  };
}
