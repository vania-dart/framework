import 'base_http_exception.dart';

class UnauthorizedException extends BaseHttpResponseException {
  UnauthorizedException({required super.message, required super.code});
}
