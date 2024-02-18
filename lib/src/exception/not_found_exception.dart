import 'dart:io';

import 'package:vania/vania.dart';

class NotFoundException extends BaseHttpException {
  NotFoundException({
    super.message = '<b>Not Fount 404</b>',
    super.code = HttpStatus.notFound,
    super.errorCode = 'Not found 404',
    super.responseType = ResponseType.json,
  });
}
