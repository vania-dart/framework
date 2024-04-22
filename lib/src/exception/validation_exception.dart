import 'dart:io';

import 'base_http_exception.dart';

class ValidationException extends BaseHttpResponseException {
  ValidationException(
      {required super.message,
      super.code = HttpStatus.unprocessableEntity,
      super.errorCode = 'Validation Error'});
}
