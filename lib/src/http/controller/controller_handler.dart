import 'dart:convert';
import 'dart:io';
import 'package:vania/src/exception/invalid_argument_exception.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/vania.dart';

class ControllerHandler {
  final RouteData route;
  final Request request;
  ControllerHandler({required this.route, required this.request}) {
    handler();
  }

  void handler() async {
    List<dynamic> positionalArguments = [];
    Function? function;
    if (route.action is Function) {
      function = route.action;
    }

    if (function == null) {
      request.response.statusCode = HttpStatus.internalServerError;
      if (request.request.headers.contentType.toString() ==
          "application/json") {
        request.response.headers.contentType = ContentType.json;

        request.response.write(jsonEncode({'message': 'Method not found'}));
      } else {
        request.response.headers.contentType = ContentType.html;
        request.response.write('<b>Method not found</b>');
      }
      request.response.close();
      return;
    }

    Map<String, dynamic> params = {};

    params.addAll(route.params ?? {});

    var argsList = extractFunctionArgs(function);

    var requestArgIndex = argsList.indexOf("Request");

    if (requestArgIndex > -1) {
      argsList.removeAt(requestArgIndex);
    }

    if (argsList.isNotEmpty) {
      positionalArguments = params.values
          .map((item) => int.tryParse(item.toString()) ?? item)
          .toList();
    }

    if (requestArgIndex > -1) {
      positionalArguments.insert(requestArgIndex, request);
    }

    try {
      Response data = await Function.apply(function, positionalArguments, {});
      data.makeResponse(request.response);
    } on BaseHttpResponseException catch (e) {
      e.call().makeResponse(request.response);
    } on InvalidArgumentException catch (_) {
      rethrow;
    }
  }

  List extractFunctionArgs(Function function) {
    String functionString = function.toString();
    String paramsString = functionString.split(RegExp(r'\(|\)'))[1].trim();

    RegExp regex = RegExp(r'(.+?)\s*\{(.+?)\}');
    Match? match =
        regex.firstMatch(paramsString.replaceAll('[', '').replaceAll(']', ''));

    if (match == null) {
      return removeDynamicPart(paramsString)
          .replaceAll('[', '')
          .replaceAll(']', '')
          .split(',');
    } else {
      return removeDynamicPart(match.group(1).toString()).split(',');
    }
  }
}

String removeDynamicPart(String input) {
  RegExp regExp = RegExp(r'\{[^\}]*\}');
  return input.replaceAll(regExp, '');
}
