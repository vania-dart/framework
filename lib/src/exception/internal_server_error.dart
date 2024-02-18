import 'dart:io';

import 'base_http_exception.dart';

class InternalServerError extends BaseHttpException {
  InternalServerError(
      {required super.message,
      super.code = HttpStatus.internalServerError,
      super.errorCode = 'Internal server error'});
}
