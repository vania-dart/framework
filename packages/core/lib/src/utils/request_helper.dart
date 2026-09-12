import 'dart:io';

import '../http/request/request_body.dart' show RequestBody;
import '../http/request/request_scope.dart' show currentRequestScope;

HttpRequest? get _current => currentRequestScope?.request;

T? getParam<T>(String key, [dynamic defualtValue]) {
  final req = _current;
  dynamic param = req?.uri.queryParameters[key];

  if (param == null && defualtValue == null) {
    return null;
  }

  param ??= defualtValue;

  final typeName = T.toString();
  if (typeName == 'int') return int.tryParse(param.toString()) as T;
  if (typeName == 'bool') return bool.tryParse(param.toString()) as T;
  if (typeName == 'num') return num.tryParse(param.toString()) as T;
  if (typeName == 'double') return double.tryParse(param.toString()) as T;
  return param as T;
}

Uri get requestUri => _current!.uri;
String? get clienIp => _current?.connectionInfo?.remoteAddress.address;
HttpHeaders? get requestHeaders => _current?.headers;
ContentType? get requestContentType => _current?.headers.contentType;
String? get method => _current?.method.toUpperCase();
HttpResponse get httpResponse => _current!.response;

Future requestBody() async {
  final req = _current;
  if (req == null) return <String, dynamic>{};
  final m = req.method.toLowerCase();
  if (m == 'post' || m == 'patch' || m == 'put' || m == 'delete') {
    return await RequestBody.extractBody(request: req);
  }
  return <String, dynamic>{};
}
