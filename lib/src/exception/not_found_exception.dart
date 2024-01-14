


import 'dart:io';

import 'base_http_exception.dart';

class NotFoundException extends BaseHttpException {
  NotFoundException({
    required super.message,
    super.code = HttpStatus.notFound,
    super.errorCode = 'Not found 404'
  });
}