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
      ? Response.html(message)
      : Response.json(message is Map ? message : {'message': message}, code);
}
