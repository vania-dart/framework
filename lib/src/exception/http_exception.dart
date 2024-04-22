import '../http/response/response.dart';
import 'base_http_exception.dart';

class HttpResponseException extends BaseHttpResponseException {
  HttpResponseException(
      {required super.message,
      required super.code,
      super.responseType = ResponseType.json,
      super.errorCode = 'Error'});
}
