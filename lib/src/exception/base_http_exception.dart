import 'package:vania/src/http/response/response.dart';

class BaseHttpResponseException {
  final String errorCode;
  final dynamic message;
  final ResponseType responseType;
  final int code;

  const BaseHttpResponseException({
    required this.message,
    required this.code,
    required this.errorCode,
    this.responseType = ResponseType.json,
  });

  Response response(bool isJson) => isJson
      ? Response.json({'message': message}, code)
      : Response.html(message);
}
