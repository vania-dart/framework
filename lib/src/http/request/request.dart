import 'dart:convert';
import 'dart:io';
import 'package:vania/src/exception/validation_exception.dart';
import 'package:vania/src/http/request/request_body.dart';
import 'package:vania/src/http/validation/validator.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/src/view_engine/template_engine.dart';
import 'package:vania/vania.dart';

class Request {
  final HttpRequest request;
  final RouteData? route;

  Request.from({required this.request, this.route});

  Map? get user => Auth().user();

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
  final Map<String, dynamic> _cookies = <String, dynamic>{};

  /// Gets a cookie by name and casts it to type [T].
  ///
  /// If the cookie doesn't exist, it returns `null`.
  ///
  /// If [T] is [String], it's casted to a string.
  /// If [T] is [bool], it's parsed from a string.
  /// If [T] is [int], it's parsed from a string.
  /// If [T] is [double], it's parsed from a string.
  /// Otherwise, it's casted to [T].
  ///
  T? cookie<T>(String key) {
    if (_cookies[key] == null) return null;
    return switch (T.toString()) {
      'String' => _cookies[key].toString(),
      'bool' => bool.parse(_cookies[key]) as T,
      'int' => int.parse(_cookies[key]) as T,
      'double' => double.parse(_cookies[key]) as T,
      (_) => _cookies[key],
    };
  }

  /// Extracts the cookies from the headers and stores them in [_cookies].
  ///
  /// The format of the [HttpHeaders.cookieHeader] is:
  void _extractCookies() {
    List<String>? cookies = _httpHeaders[HttpHeaders.cookieHeader];
    if (cookies == null) {
      return;
    }
    for (String cookie in cookies) {
      List cookies = cookie.split(';');
      for (String cookie in cookies) {
        List cookieList = cookie.split('=');
        _cookies[cookieList[0].trim()] = cookieList[1].trim();
      }
    }
  }

  Future<Request> extractBody() async {
    _extractCookies();
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

  bool isMethod(String method) {
    return route?.method.toLowerCase() == method.toLowerCase();
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

  Map json(String key) {
    if (_all[key] != null && _all[key] is String) {
      return jsonDecode(_all[key]);
    }

    if (_all[key] != null && _all[key] is Map) {
      return _all[key];
    }

    return {};
  }

  dynamic input([String? key, dynamic defaultVal]) {
    if (key == null) {
      return _all;
    }

    if (_all[key] != null) {
      return int.tryParse(_all[key].toString()) ?? _all[key];
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

  int? integer(String key) {
    return int.tryParse(_all[key].toString());
  }

  double? asDouble(String key) {
    return double.tryParse(_all[key].toString());
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

  void validate(dynamic rules,
      [Map<String, String> messages = const <String, String>{}]) {
    assert(rules is Map<String, String> || rules is List<Validation>,
        'Rules must be either Map<String, String> or List<Validation>.');
    TemplateEngine().sessionErrors.clear();
    if (rules is Map<String, String>) {
      _validate(rules, messages);
    } else {
      _validateChain(rules as List<Validation>);
    }
  }

  void _validate(Map<String, String> rules,
      [Map<String, String> messages = const <String, String>{}]) {
    Validator validator = Validator(data: all());
    if (messages.isNotEmpty) {
      validator.setNewMessages(messages);
    }
    validator.validate(rules);
    if (validator.hasError) {
      bool isHtml = request.headers.value('accept').toString().contains('html');
      if (isHtml) {
        TemplateEngine().sessionErrors.addAll(validator.errors);
      }
      throw ValidationException(message: validator.errors);
    }
  }

  void _validateChain(List<Validation> validations) {
    Map<String, String> errors = {};
    final data = all();
    for (Validation validation in validations) {
      dynamic fieldValue =
          data.containsKey(validation.field) ? data[validation.field] : null;
      for (ValidationRule rule in validation.rules) {
        if (!rule.validate(fieldValue, data)) {
          errors[validation.field] = rule.errorMessage;
          break; // Stop at the first failed validation per field
        }
      }
    }
    if (errors.isNotEmpty) {
      bool isHtml = request.headers.value('accept').toString().contains('html');
      if (isHtml) {
        TemplateEngine().sessionErrors.addAll(errors);
      }
      throw ValidationException(message: errors);
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
