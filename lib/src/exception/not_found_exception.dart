import 'dart:io';
import '../http/response/response.dart';
import 'base_http_exception.dart';

class NotFoundException extends BaseHttpResponseException {
  NotFoundException({
    super.message = 'Not Fount 404',
    super.code = HttpStatus.notFound,
    super.errorCode = 'Not found 404',
    super.responseType = ResponseType.html,
  });
}
