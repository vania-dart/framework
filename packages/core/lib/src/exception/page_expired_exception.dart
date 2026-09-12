import 'package:vania/src/http/response/response.dart';

import 'base_http_exception.dart';

class PageExpiredException extends BaseHttpResponseException {
  const PageExpiredException({
    super.message = '<center><h1>Page Expired (419)</h1></center>',
    super.code = 419,
    super.responseType = ResponseType.html,
  });
}
