import 'package:vania/http/request.dart' show Request;

class VaniaGraphQLContext {
  VaniaGraphQLContext({
    this.request,
    this.rootValue,
    Map<String, dynamic> values = const {},
  }) : values = Map<String, dynamic>.from(values);

  static const variableKey = r'__vania_context';

  final Request? request;
  final Object? rootValue;
  final Map<String, dynamic> values;

  String? get ip => request?.ip;
  Uri? get uri => request?.uri;
  Map? get user => request?.user;
  String? get method => request?.request.method;

  dynamic operator [](String key) => values[key];

  void set(String key, dynamic value) {
    values[key] = value;
  }

  String? header(String name) {
    return request?.request.headers.value(name);
  }

  Map<String, dynamic> toGlobalVariables() {
    return {variableKey: this, ...values};
  }
}
