import 'package:vania/vania.dart';

class HttpException extends BaseHttpException {
  HttpException(
      {required super.message,
      required super.code,
      super.responseType = ResponseType.json,
      super.errorCode = 'Error'});
}
