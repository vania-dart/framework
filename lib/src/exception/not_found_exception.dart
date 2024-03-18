import 'dart:io';

import 'package:vania/vania.dart';

class NotFoundException extends BaseHttpException {
  NotFoundException({
    super.message = 'Not Fount 404',
    super.code = HttpStatus.notFound,
    super.errorCode = 'Not found 404',
    super.responseType = ResponseType.json,
  });
}
