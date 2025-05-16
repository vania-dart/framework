import '../http/response/response.dart';
import 'base_http_exception.dart';

class ThrottleException extends BaseHttpResponseException {
  final Map<String, String>? headers;

  ThrottleException({
    required String super.message,
    required super.code,
    this.headers,
  });

  @override
  Response response(bool isHtml) {
    if (isHtml) {
      return Response.html(message);
    }

    final Map<String, dynamic> responseData = message is Map
        ? Map<String, dynamic>.from(message as Map)
        : {'message': message};

    if (headers != null) {
      return Response.jsonWithHeader(responseData,
          statusCode: code, headers: headers!);
    }

    return Response.json(responseData, code);
  }
}
