import 'dart:io';
import 'package:vania/src/exception/validation_exception.dart';
import 'package:vania/src/http/request/request_body.dart';
import 'package:vania/src/http/validation/validator.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/vania.dart';

class Request {
  final HttpRequest request;
  final RouteData? route;

  Request.from({required this.request, this.route});

  String? get ip => request.connectionInfo?.remoteAddress.address;

  HttpHeaders get _httpHeaders => request.headers;

  ContentType? get contentType => request.headers.contentType;

  Uri get uri => request.uri;

  String? get path => route?.path;

  String get url => "$host$uri";

  String get host => header(HttpHeaders.hostHeader) ?? 'unknown';

  String? get method => route?.method;

  HttpResponse get response => request.response;

  Map<String, dynamic> get _all => all();

  Map<String, dynamic> get _query => uri.queryParameters;

  Map<String, dynamic> body = <String, dynamic>{};

  bool isMethod(String method) {
    return route?.method.toLowerCase() == method.toLowerCase();
  }

  Future<Request> extractBody() async {
    final whereMethod = ['post', 'patch', 'put']
        .where((method) => method == request.method.toLowerCase())
        .toList();
    if (whereMethod.isNotEmpty) {
      body = await RequestBody.extractBody(request: request);
    }
    return this;
  }

  Map<String, dynamic> all() {
    return {...body, ..._query, ...params()};
  }

  Map<String, dynamic> params() {
    final vParams = route?.params ?? {};
    vParams.removeWhere((key, value) => value is Request);
    return vParams;
  }

  Map<String, dynamic> only(List<String> keys) {
    Map<String, dynamic> ret = <String, dynamic>{};
    for (String key in keys) {
      ret[key] = _all[key];
    }
    return ret;
  }

  bool has(dynamic key) {
    if (key is String) {
      String? val = _all[key];
      if (val == null) {
        return false;
      }
      return val.toString().isNotEmpty ? true : false;
    }

    if (key is List<String>) {
      bool hasKey = true;
      for (String vkey in key) {
        if (_all[vkey] == null) {
          hasKey = false;
        }
      }
      return hasKey;
    }

    return false;
  }

  bool hasAny(List<String> keys) {
    bool hasKey = false;
    for (String key in keys) {
      if (_all[key] != null) {
        hasKey = true;
      }
    }
    return hasKey;
  }

  Future whenHas(String key) async {
    if (_all[key] != null) {
      return Future.value(_all[key]);
    } else {
      return Future.error("");
    }
  }

  Map<String, dynamic> except(dynamic key) {
    Map<String, dynamic> requestItems = _all;

    if (key is List<String>) {
      for (String vKey in key) {
        requestItems.removeWhere((iKey, value) => iKey == vKey);
      }
    }

    if (key is String) {
      requestItems.removeWhere((vkey, value) => vkey == key);
    }

    return requestItems;
  }

  dynamic input([String? key, dynamic defaultVal]) {
    if (key == null) {
      return _all;
    }

    if (_all[key] != null) {
      return _all[key];
    }

    if (defaultVal != null) {
      return defaultVal;
    }

    return null;
  }

  RequestFile? file(String key) {
    if (_all[key] == null) {
      return null;
    }

    if (_all[key] is! RequestFile) {
      return (_all[key] as List<RequestFile>).first;
    }

    return _all[key];
  }

  List<RequestFile>? files(String key) {
    if (_all[key] == null) {
      return null;
    }

    var files = _all[key];

    if (files is! List) {
      return [files];
    }
    return files as List<RequestFile>;
  }

  String string(String key) {
    return _all[key].toString();
  }

  bool boolean(String key) {
    try {
      return bool.parse(_all[key].toString());
    } catch (_) {
      return false;
    }
  }

  DateTime? date(String key) {
    try {
      return DateTime.parse(_all[key].toString());
    } catch (_) {
      return null;
    }
  }

  dynamic query([
    String? key,
    String? defaultVal,
  ]) {
    if (key == null) {
      return _query.values;
    }

    if (_query[key] != null) {
      return _query[key];
    }

    if (defaultVal != null) {
      return defaultVal;
    }

    return null;
  }

  void merge(Map<String, dynamic> values) {
    _all.addAll(values);
    body = <String, dynamic>{...body, ...values};
  }

  void mergeIfMissing(Map<String, dynamic> values) {
    for (var vKey in values.keys) {
      if (!_all.keys.contains(vKey)) {
        _all.addEntries(values[vKey]);
      }
    }
  }

  String? header(String key, [String? defaultHeader]) {
    return _httpHeaders.value(key) ?? defaultHeader;
  }

  Map<String, dynamic> get headers {
    Map<String, dynamic> ret = <String, dynamic>{};
    _httpHeaders.forEach((String name, List<String> values) {
      ret[name] = values.join();
    });
    return ret;
  }

  bool isFormData() {
    return RequestBody.isFormData(contentType);
  }

  /// http request data is json
  bool isJson() {
    return RequestBody.isJson(contentType);
  }

  /// http request data is json
  bool isUrlencoded() {
    return RequestBody.isUrlencoded(contentType);
  }

  String? userAgent() {
    return header(HttpHeaders.userAgentHeader);
  }

  String? origin() {
    return header('origin');
  }

  String? referer() {
    return header(HttpHeaders.refererHeader);
  }

  void validate(Map<String, String> rules,
      [Map<String, String> messages = const <String, String>{}]) {
    Validator validator = Validator(data: all());
    if (messages.isNotEmpty) {
      validator.setNewMessages(messages);
    }
    validator.validate(rules);
    if (validator.hasError) {
      throw ValidationException(message: validator.errors);
    }
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> ret = <String, dynamic>{};
    _all.forEach((String key, dynamic value) {
      if (value is RequestFile) {
        ret[key] = value.filename;
      } else {
        ret[key] = value;
      }
    });
    return ret;
  }
}
