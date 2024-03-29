import '../http/response/response.dart';
import 'base_http_exception.dart';

class HttpException extends BaseHttpException {
  HttpException(
      {required super.message,
      required super.code,
      super.responseType = ResponseType.json,
      super.errorCode = 'Error'});
}
