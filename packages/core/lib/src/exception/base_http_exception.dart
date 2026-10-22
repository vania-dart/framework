import 'dart:convert' show htmlEscape;

import 'package:vania/src/http/response/response.dart';

class BaseHttpResponseException {
  final dynamic message;
  final ResponseType responseType;
  final int code;

  const BaseHttpResponseException({
    required this.message,
    required this.code,
    this.responseType = ResponseType.json,
  });

  Response response(bool isHtml) => isHtml
      ? Response.html(htmlText, statusCode: code)
      : Response.json(message is Map ? message : {'message': message}, code);

  /// [message] as text for an HTML page, escaped: it may echo request
  /// input. A map message shows its `message` entry.
  String get htmlText {
    final m = message;
    final text = m is Map && m.containsKey('message') ? m['message'] : m;
    return htmlEscape.convert(text.toString());
  }
}
