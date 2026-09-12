import 'dart:io';

import 'package:vania/src/exception/base_http_exception.dart';
import 'package:vania/src/http/response/response.dart';

class ForbiddenException extends BaseHttpResponseException {
  ForbiddenException({
    super.message = 'Forbidden',
    super.code = HttpStatus.forbidden,
    super.responseType = ResponseType.json,
  });
}
