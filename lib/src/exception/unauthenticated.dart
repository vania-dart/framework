import 'dart:io';

import 'base_http_exception.dart';

class Unauthenticated extends BaseHttpResponseException {
  Unauthenticated(
      {required super.message,
      super.code = HttpStatus.unauthorized,
      super.errorCode = 'Unauthenticated'});
}
