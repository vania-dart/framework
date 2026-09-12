import 'dart:io';

import '../http/response/response.dart';
import 'base_http_exception.dart';

class RedirectException extends BaseHttpResponseException {
  RedirectException({
    super.message,
    super.code = HttpStatus.found,
    super.responseType = ResponseType.html,
  });
}
