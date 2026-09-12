import 'dart:convert' show htmlEscape;

import 'package:vania/env.dart' show env;
import 'package:vania/src/exception/database_exception.dart';
import 'package:vania/src/logger/logger.dart';
import 'package:vania/src/exception/query_exception.dart';
import 'package:vania/src/exception/validation_exception.dart';
import 'package:vania/src/http/request/request.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/src/route/route_history.dart';

import '../../exception/base_http_exception.dart';
import '../../exception/invalid_argument_exception.dart';

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

  Future<void> create({
    required RouteData route,
    required Request request,
  }) async {
    List<dynamic> positionalArguments = [];
    if (route.params != null) {
      try {
        positionalArguments = route.params!.values
            .map((param) => _getParamValue(param.toString()))
            .toList();
      } on FormatException catch (e, stack) {
        return _fail(request, e, stack, 500);
      }
    }

    if (route.hasRequest) {
      positionalArguments.insert(0, request);
    }

    try {
      Response response = await Function.apply(
        route.action,
        positionalArguments,
        {},
      );

      await response.makeResponse(request.response);
    } on ValidationException catch (error) {
      bool isHtml = request.request.headers
          .value('accept')
          .toString()
          .contains('html');
      if (isHtml) {
        await Response.redirect(
          RouteHistory().previousRoute,
        ).makeResponse(request.response);
      } else {
        await error.response(false).makeResponse(request.response);
      }
    } on BaseHttpResponseException catch (error, stack) {
      // Exceptions the application raised deliberately (401, 403, 404,
      // 419, 429 …). Their message is written for the client, so it is
      // safe to pass through — but a 5xx raised this way is still an
      // internal failure and gets the same treatment as any other.
      if (error.code >= 500) {
        await _fail(request, error, stack, error.code);
      } else {
        await _send(request, error.message, error.code);
      }
    } on InvalidArgumentException catch (error, stack) {
      await _fail(request, error, stack, 500);
    } on DatabaseException catch (error, stack) {
      await _fail(request, error, stack, 500);
    } on QueryException catch (error, stack) {
      await _fail(request, error, stack, 500);
    } catch (error, stack) {
      await _fail(request, error, stack, 500);
    }
  }
}

/// Handles an internal failure: logs it with its stack trace, and only
/// reveals the underlying message when `APP_DEBUG` is on.
///
/// Driver errors routinely carry SQL text, table and column names, so
/// they are not returned to the client outside debug mode.
Future<void> _fail(
  Request req,
  Object error,
  StackTrace stack,
  int statusCode,
) async {
  Logger.log('$error\n$stack', type: Logger.ERROR);
  final message = env<bool>('APP_DEBUG', false)
      ? error.toString()
      : 'Internal Server Error';
  await _send(req, message, statusCode);
}

Future<void> _send(Request req, String message, int statusCode) async {
  if (req.headers['accept'].toString().contains('html')) {
    // Escape before embedding in HTML. Error text routinely contains
    // caller-supplied input (a bad route param, a rejected field value),
    // so writing it raw turned any error path into reflected XSS.
    await Response.html(
      htmlEscape.convert(message),
      statusCode: statusCode,
    ).makeResponse(req.response);
  } else {
    await Response.json({
      "message": message,
    }, statusCode).makeResponse(req.response);
  }
}
