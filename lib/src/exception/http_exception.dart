import 'dart:io';
import 'base_http_exception.dart';

class HttpResponseException extends BaseHttpResponseException {
  HttpResponseException({
    super.message,
    super.code = HttpStatus.found,
  });
}
