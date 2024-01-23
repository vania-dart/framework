import 'dart:convert';
import 'dart:io';
import 'package:vania/src/exception/invalid_argument_exception.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/vania.dart';

class ControllerHandler {
  final RouteData route;
  final Request request;
  const ControllerHandler({required this.route, required this.request});

  void call() async {
    List<dynamic> positionalArguments = [];
    Map<Symbol, dynamic> namedArguments = {};
    Function? function;
    if (route.action is Function) {
      function = route.action;
    } else {
      function = getDefaultControllerMethodName(route);
    }

    Map<String, dynamic> params = {};

    params.addAll(route.params ?? {});

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

    String requestArgName = getRequestVar(function.toString());

    if (requestArgName.isNotEmpty) {
      params[requestArgName] = request;
    }

    var argsList = extractFunctionArgs(function);

    argsList.removeWhere(
        (item) => item == "" || item == null || item.toString().isEmpty);

    var requestArgIndex = argsList.indexOf("Request");

    if (requestArgIndex > -1) {
      argsList.removeAt(requestArgIndex);
    }

    if (argsList.isNotEmpty) {
      var parmsList = params.values.toList();
      int counter = 0;
      do {
        var value = parmsList[counter];
        value = int.tryParse(value) ?? value;
        positionalArguments.add(value);
        params.removeWhere((_, val) => val == value.toString());
        counter++;
      } while (argsList.length > counter);
    }

    if (requestArgIndex > -1) {
      positionalArguments.insert(requestArgIndex, request);
    }

    namedArguments = params.map(
        (key, value) => MapEntry(Symbol(key), int.tryParse(value) ?? value));

    try {
      Response data =
          await Function.apply(function, positionalArguments, namedArguments);
      data.makeResponse(request.response);
    } on BaseHttpException catch (e) {
      e.call().makeResponse(request.response);
    }on InvalidArgumentException catch(e){
      print(e.message);
    }
  }

  Function? getDefaultControllerMethodName(RouteData route) {
    try {
      switch (route.method) {
        case 'GET':
          if (route.params?.keys.first != null) {
            return route.action.show;
          }
          return route.action.index;
        case 'POST':
          return route.action.store;
        case 'PUT':
          return route.action.update;
        case 'PATCH':
          return route.action.patch;
        case 'DELETE':
          return route.action.destroy;
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  String getRequestVar(String input) {
    RegExp pattern = RegExp(r"Request\?\s*([a-zA-Z0-9_]+)");

    Match? match = pattern.firstMatch(input);

    if (match != null) {
      String secondPart = match.group(1) ?? '';
      return secondPart;
    } else {
      return '';
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
