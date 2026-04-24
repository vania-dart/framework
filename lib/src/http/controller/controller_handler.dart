import 'package:vania/src/exception/database_exception.dart';
import 'package:vania/src/exception/exception_handler.dart';
import 'package:vania/src/exception/query_exception.dart';
import 'package:vania/src/exception/validation_exception.dart';
import 'package:vania/src/http/request/request.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/src/route/route_history.dart';
import 'package:vania/application.dart';

import '../../exception/base_http_exception.dart';
import '../../exception/invalid_argument_exception.dart';

class ControllerHandler {
  dynamic _getParamValue(String param) {
    if (int.tryParse(param) != null) {
      return int.parse(param);
    } else if (num.tryParse(param) != null) {
      return double.parse(param);
    } else if (double.tryParse(param) != null) {
      return num.parse(param);
    } else if (param.toLowerCase() == 'true') {
      return true;
    } else if (param.toLowerCase() == 'false') {
      return false;
    } else {
      return param;
    }
  }

  void create({required RouteData route, required Request request}) async {
    List<dynamic> positionalArguments = [];
    if (route.params != null) {
      try {
        positionalArguments = route.params!.values
            .map((param) => _getParamValue(param.toString()))
            .toList();
      } on FormatException catch (e) {
        _response(request, e.message, 500);
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

      response.makeResponse(request.response);
    } on ValidationException catch (error) {
      Response? customResponse = _handleException(error, request);
      if (customResponse != null) {
        return customResponse.makeResponse(request.response);
      }
      bool isHtml = request.request.headers
          .value('accept')
          .toString()
          .contains('html');
      if (isHtml) {
        Response.redirect(
          RouteHistory().previousRoute,
        ).makeResponse(request.response);
      } else {
        error.response(false).makeResponse(request.response);
      }
    } on InvalidArgumentException catch (error) {
      Response? customResponse = _handleException(error, request);
      if (customResponse != null) {
        return customResponse.makeResponse(request.response);
      }
      _response(request, error.message);
    } on DatabaseException catch (error) {
      Response? customResponse = _handleException(error, request);
      if (customResponse != null) {
        return customResponse.makeResponse(request.response);
      }
      _response(request, error.message, 500);
    } on QueryException catch (error) {
      Response? customResponse = _handleException(error, request);
      if (customResponse != null) {
        return customResponse.makeResponse(request.response);
      }
      _response(request, error.cause ?? '', 500);
    } on BaseHttpResponseException catch (error) {
      Response? customResponse = _handleException(error, request);
      if (customResponse != null) {
        return customResponse.makeResponse(request.response);
      }
      _response(request, error.message, error.code);
    } catch (error) {
      Response? customResponse = _handleException(error, request);
      if (customResponse != null) {
        return customResponse.makeResponse(request.response);
      }
      _response(request, error.toString());
    }
  }

  Response? _handleException(dynamic exception, Request request) {
    try {
      ExceptionHandler? handler =
          Application().getExceptionHandler(exception.runtimeType);
      if (handler != null) {
        return handler.handle(exception, request);
      }
      GeneralExceptionHandler? generalHandler =
          Application().getGeneralExceptionHandler();
      if (generalHandler != null) {
        return generalHandler.handle(exception, request);
      }
    } catch (_) {}
    return null;
  }
}

void _response(Request req, message, [statusCode = 500]) {
  if (req.headers['accept'].toString().contains('html')) {
    Response.html(message).makeResponse(req.response);
  } else {
    Response.json({"message": message}, statusCode).makeResponse(req.response);
  }
}
