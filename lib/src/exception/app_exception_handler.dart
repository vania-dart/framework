import 'package:vania/src/exception/database_exception.dart';
import 'package:vania/src/exception/exception_handler.dart';
import 'package:vania/src/exception/not_found_exception.dart';
import 'package:vania/src/exception/query_exception.dart';
import 'package:vania/src/exception/validation_exception.dart';
import 'package:vania/src/http/request/request.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/service/service_provider.dart';
import 'package:vania/application.dart';

class DatabaseExceptionHandler extends ExceptionHandler<DatabaseException> {
  @override
  Response handle(DatabaseException exception, Request request) {
    return Response.json({
      'success': false,
      'message': 'Database error occurred',
      'error': exception.message,
    }, 500);
  }
}

class QueryExceptionHandler extends ExceptionHandler<QueryException> {
  @override
  Response handle(QueryException exception, Request request) {
    return Response.json({
      'success': false,
      'message': 'Query error occurred',
      'error': exception.cause,
    }, 500);
  }
}

class NotFoundExceptionHandler extends ExceptionHandler<NotFoundException> {
  @override
  Response handle(NotFoundException exception, Request request) {
    return Response.json({
      'success': false,
      'message': exception.message,
    }, 404);
  }
}

class ValidationExceptionHandler extends ExceptionHandler<ValidationException> {
  @override
  Response handle(ValidationException exception, Request request) {
    return Response.json({
      'success': false,
      'message': 'Validation failed',
      'errors': exception.message,
    }, 422);
  }
}

class ThirdPartyExceptionHandler extends GeneralExceptionHandler {
  @override
  Response? handle(dynamic exception, Request request) {
    return Response.json({
      'success': false,
      'message': 'An unexpected error occurred',
      'error': exception.toString(),
    }, 500);
  }
}

class AppExceptionServiceProvider extends ServiceProvider {
  @override
  Future<void> boot() async {}

  @override
  Future<void> register() async {
    Application().addExceptionHandlers({
      DatabaseException: DatabaseExceptionHandler(),
      QueryException: QueryExceptionHandler(),
      NotFoundException: NotFoundExceptionHandler(),
      ValidationException: ValidationExceptionHandler(),
    });
    Application().setGeneralExceptionHandler(
      ThirdPartyExceptionHandler(),
    );
  }
}
