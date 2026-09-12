import 'dart:convert';
import 'package:vania/src/http/session/flash_messages.dart';
import 'dart:io';
import 'package:vania/env.dart' show env;
import 'package:vania/src/contract/http/request/form_validation.dart';
import 'package:vania/src/exception/validation_exception.dart';
import 'package:vania/src/http/request/request_body.dart';
import 'package:vania/src/http/request/request_file.dart';
import 'package:vania/src/http/validation/custom_validation_rule.dart';
import 'package:vania/src/http/validation/validation_chain/validation.dart';
import 'package:vania/src/http/validation/validation_chain/validation_rule.dart'
    show ValidationRule;
import 'package:vania/src/http/validation/validator.dart';
import 'package:vania/src/route/route_data.dart';

import '../../exception/unauthorized_exception.dart';
import '../validation/field_validation.dart';

typedef RequestUserResolver = Map? Function();

RequestUserResolver? _requestUserResolver;

/// Register the resolver invoked by [Request.user]. Called from
/// `vania_auth`'s service provider (or any custom auth integration).
void setRequestUserResolver(RequestUserResolver resolver) {
  _requestUserResolver = resolver;
}

void clearRequestUserResolver() {
  _requestUserResolver = null;
}

class Request {
  late HttpRequest request;
  RouteData? route;

  Request from({required HttpRequest request, RouteData? route}) {
    this.request = request;
    this.route = route;

    return this;
  }

  Map? get user => _requestUserResolver?.call();

  /// The address of the socket this request arrived on.
  ///
  /// Behind a reverse proxy this is the proxy's address, the same for
  /// every client. Use [clientIp] when you need the originating address.
  String? get ip => request.connectionInfo?.remoteAddress.address;

  /// The originating client address.
  ///
  /// Returns [ip] unless `TRUSTED_PROXIES` names the peer, in which case
  /// the left-most entry of `X-Forwarded-For` is returned instead.
  ///
  /// `X-Forwarded-For` is trivially spoofed by the client, so it is only
  /// consulted when the request actually came from a proxy you listed.
  /// `TRUSTED_PROXIES` is a comma-separated list of addresses; the value
  /// `*` trusts any peer and should only be used when something else
  /// guarantees the app is unreachable except through the proxy.
  String? get clientIp {
    final peer = ip;
    if (peer == null) return null;

    final trusted = env<String>(
      'TRUSTED_PROXIES',
      '',
    ).split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (trusted.isEmpty) return peer;
    if (!trusted.contains('*') && !trusted.contains(peer)) return peer;

    final forwarded = header('x-forwarded-for');
    if (forwarded == null || forwarded.isEmpty) return peer;

    final first = forwarded.split(',').first.trim();
    return first.isEmpty ? peer : first;
  }

  HttpHeaders get _httpHeaders => request.headers;

  ContentType? get contentType => request.headers.contentType;

  Uri get uri => request.uri;

  String? get path => route?.path;

  String get url => "$host$uri";

  String get host => header(HttpHeaders.hostHeader) ?? 'unknown';

  String? get method => route?.method;

  HttpResponse get response => request.response;

  Map<String, dynamic> get _query => uri.queryParameters;

  Map<String, dynamic> body = <String, dynamic>{};
  final Map<String, dynamic> _cookies = <String, dynamic>{};

  Map<String, dynamic>? _allData;

  void _rebuildAll() {
    _allData = <String, dynamic>{...body, ..._query, ...params()};
  }

  Map<String, dynamic> get _all =>
      _allData ??= <String, dynamic>{...body, ..._query, ...params()};

  List<CustomValidationRule>? _customRules;

  Request setCustomRule(List<CustomValidationRule> customRule) {
    _customRules = customRule;
    return this;
  }

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
  /// Malformed pairs (no `=`) are skipped. Values
  /// that contain `=` characters (e.g. base64 with `=` padding) are
  /// preserved by rejoining everything after the first `=`.
  void _extractCookies() {
    final List<String>? cookies = _httpHeaders[HttpHeaders.cookieHeader];
    if (cookies == null) return;
    for (final header in cookies) {
      for (final pair in header.split(';')) {
        final eq = pair.indexOf('=');
        if (eq <= 0) continue; // no `=` or empty key
        final name = pair.substring(0, eq).trim();
        final value = pair.substring(eq + 1).trim();
        if (name.isEmpty) continue;
        _cookies[name] = value;
      }
    }
  }

  bool _bodyExtracted = false;

  /// Extracts the request body (form-data / json / urlencoded) into [body]
  /// and prepares the merged view of body+query+params.
  ///
  /// Idempotent: only the first call reads the socket. CSRF middleware
  /// can materialise the `_csrf`/`_token` fields early and the request
  /// handler can still call it afterwards without consuming the stream
  /// twice.
  Future<Request> extractBody() async {
    if (_bodyExtracted) return this;
    _bodyExtracted = true;
    _extractCookies();
    final method = request.method.toLowerCase();
    if (method == 'post' ||
        method == 'patch' ||
        method == 'put' ||
        method == 'delete') {
      body = await RequestBody.extractBody(request: request);
    }
    _rebuildAll();
    return this;
  }

  Map<String, dynamic> all() {
    return Map.unmodifiable(_all);
  }

  Map<String, dynamic> params() {
    return route?.params ?? const <String, dynamic>{};
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

  bool has(dynamic keys) {
    if (keys is String) {
      String? val = _all[keys];
      if (val == null) {
        return false;
      }
      return val.toString().isNotEmpty ? true : false;
    }

    if (keys is List<String>) {
      bool hasKey = true;
      for (String key in keys) {
        if (_all[key] == null) {
          hasKey = false;
        }
      }
      return hasKey;
    }

    return (_all[keys] != null && _all[keys].toString().isNotEmpty);
  }

  bool hasAny(List<String> keys) {
    bool hasKey = false;
    for (String key in keys) {
      if (_all[key] != null && _all[key].toString().isNotEmpty) {
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

  /// Returns the input value for [key] as-is (no implicit int coercion).
  dynamic input([String? key, dynamic defaultVal]) {
    if (key == null) return _all;
    final value = _all[key];
    if (value != null) return value;
    return defaultVal;
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

  bool hasFile(String key) =>
      (_all[key].toString().isNotEmpty &&
      (file(key) != null || files(key) != null));

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

  List asList(String key) {
    return List.from(_all[key]);
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

  dynamic query([String? key, String? defaultVal]) {
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
    // Existing keys are overwritten. The body is the source of truth for
    // POST/PUT/PATCH, so the values land there; the merged view is
    // patched too, so query-string keys of the same name are overridden
    // as well.
    body.addAll(values);
    (_allData ??= <String, dynamic>{
      ...body,
      ..._query,
      ...params(),
    }).addAll(values);
  }

  void mergeIfMissing(Map<String, dynamic> values) {
    final view = _all;
    var changed = false;
    for (final entry in values.entries) {
      if (!view.containsKey(entry.key)) {
        body[entry.key] = entry.value;
        view[entry.key] = entry.value;
        changed = true;
      }
    }
    if (changed) _allData = view;
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

  bool isJson() {
    return RequestBody.isJson(contentType);
  }

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

  Future<void> validate(
    dynamic rules, [
    Map<String, String> messages = const <String, String>{},
  ]) async {
    assert(
      rules is Map<String, String> ||
          rules is List<FieldValidation> ||
          rules is List<Validation> ||
          rules is FormValidation,
      'Rules must be either Map<String, String> or List<Validation>. or FormRequest',
    );
    FlashMessages().clearErrors();
    if (rules is Map<String, String>) {
      await _validate(rules, messages);
    } else if (rules is List<FieldValidation>) {
      Map<String, String> ruleMessages = Map.from(messages);
      final rulesMap = Map.fromEntries(
        rules.map((rule) {
          ruleMessages.addAll(rule.toMapMessages);
          return MapEntry(rule.fieldName, rule.toString());
        }),
      );
      await _validate(rulesMap, ruleMessages);
    } else if (rules is FormValidation) {
      await _formRequestValidate(rules);
    } else {
      _validateChain(rules as List<Validation>);
    }
  }

  Future<void> _formRequestValidate(FormValidation formRequest) async {
    if (!formRequest.authorize()) {
      throw UnauthorizedException(message: 'Access denied', code: 403);
    }

    final rules = formRequest.rules();
    final Map<String, String> messages = formRequest.messages();

    Validator validator = Validator(data: body);

    if (formRequest.customRule().isNotEmpty) {
      validator.customRule(formRequest.customRule());
    }

    Map<String, String> rulesMap = {};
    if (rules is List<FieldValidation>) {
      rulesMap = Map.fromEntries(
        rules.map((rule) {
          messages.addAll(rule.toMapMessages);
          return MapEntry(rule.fieldName, rule.toString());
        }),
      );
    } else {
      rulesMap = formRequest.rules();
    }

    if (messages.isNotEmpty) {
      validator.setNewMessages(messages);
    }

    await validator.validate(rulesMap);
    if (validator.hasError) {
      bool isHtml = request.headers.value('accept').toString().contains('html');
      if (isHtml) {
        FlashMessages().addErrors(validator.errors);
      }
      throw ValidationException(message: validator.errors);
    }
  }

  Future<void> _validate(
    Map<String, String> rules, [
    Map<String, String> messages = const <String, String>{},
  ]) async {
    Validator validator = Validator(data: body);

    if (_customRules != null) {
      validator.customRule(_customRules!);
    }

    if (messages.isNotEmpty) {
      validator.setNewMessages(messages);
    }
    await validator.validate(rules);
    if (validator.hasError) {
      bool isHtml = request.headers.value('accept').toString().contains('html');
      if (isHtml) {
        FlashMessages().addErrors(validator.errors);
      }
      throw ValidationException(message: validator.errors);
    }
  }

  void _validateChain(List<Validation> validations) {
    Map<String, String> errors = {};
    final data = all();
    for (Validation validation in validations) {
      dynamic fieldValue = data.containsKey(validation.field)
          ? data[validation.field]
          : null;
      for (ValidationRule rule in validation.rules) {
        if (!rule.validate(fieldValue, data)) {
          errors[validation.field] = rule.errorMessage;
          break;
        }
      }
    }
    if (errors.isNotEmpty) {
      bool isHtml = request.headers.value('accept').toString().contains('html');
      if (isHtml) {
        FlashMessages().addErrors(errors);
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
