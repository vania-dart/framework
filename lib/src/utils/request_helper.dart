import 'dart:io';

import '../http/request/request_body.dart' show RequestBody;
import '../http/request/request_handler.dart' show globalHttpRequest;

T? getParam<T>(String key, [dynamic defualtValue]) {
  dynamic param = globalHttpRequest!.uri.queryParameters[key];

  if (param == null && defualtValue == null) {
    return null;
  }

  param ??= defualtValue;

  if (T.toString() == 'int') {
    return int.tryParse(param.toString()) as T;
  }

  if (T.toString() == 'bool') {
    return bool.tryParse(param.toString()) as T;
  }

  if (T.toString() == 'num') {
    return num.tryParse(param.toString()) as T;
  }

  if (T.toString() == 'double') {
    return double.tryParse(param.toString()) as T;
  }

  return param as T;
}

Uri get requestUri => globalHttpRequest!.uri;
String? get clienIp => globalHttpRequest?.connectionInfo?.remoteAddress.address;
HttpHeaders? get requestHeaders => globalHttpRequest?.headers;
ContentType? get requestContentType => globalHttpRequest?.headers.contentType;
String? get method => globalHttpRequest?.method.toUpperCase();
HttpResponse httpResponse = globalHttpRequest!.response;
Future requestBody() async {
  final whereMethod = ['post', 'patch', 'put', 'delete']
      .where((method) => method == globalHttpRequest?.method.toLowerCase())
      .toList();
  if (whereMethod.isNotEmpty) {
    return await RequestBody.extractBody(request: globalHttpRequest!);
  }
  return {};
}
