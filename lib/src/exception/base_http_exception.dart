
import 'package:vania/vania.dart';

class BaseHttpException {
  final String errorCode;
  final Map<String, String> message;
  final int code;

  const BaseHttpException(
      {required this.message, required this.code, required this.errorCode});

  Response call() => Response(
      {'message': message, 'error_code': errorCode}, ResponseType.json, code);
}
