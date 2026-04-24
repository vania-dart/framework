import 'package:vania/src/http/request/request.dart';
import 'package:vania/src/http/response/response.dart';

abstract class ExceptionHandler<T> {
  const ExceptionHandler();

  Response handle(T exception, Request? request);
}

abstract class GeneralExceptionHandler {
  const GeneralExceptionHandler();

  Response? handle(dynamic exception, Request? request);
}
