import '../service/service_provider.dart';
import 'package:vania/src/ioc_container.dart';

/// Application configuration, as supplied to `Application().initialize`.
///
/// Values are read with [get], or with the typed helpers below when the
/// expected shape is known.
class Config {
  Config.createDefault();

  factory Config() =>
      IoCContainer().resolveOrDefault<Config>(Config.createDefault);

  Map<String, dynamic> _config = {};

  set setApplicationConfig(Map<String, dynamic> conf) => _config = conf;

  dynamic get(String key) => _config[key];

  /// Reads [key] and checks its type, returning [defaultValue] when the
  /// key is absent.
  ///
  /// Throws [ConfigException] when the value is present but of another
  /// type, so a typo surfaces at the point of use rather than as a cast
  /// error somewhere further along.
  T? typed<T>(String key, [T? defaultValue]) {
    final value = _config[key];
    if (value == null) return defaultValue;
    if (value is! T) {
      throw ConfigException(
        'Config key "$key" should be a $T but is a ${value.runtimeType}.',
      );
    }
    return value;
  }

  /// Reads [key], throwing when it is missing.
  T required<T>(String key) {
    if (!_config.containsKey(key)) {
      throw ConfigException('Required config key "$key" is missing.');
    }
    return typed<T>(key) as T;
  }

  /// Validates the shape of [config] before the application boots.
  ///
  /// Checks the keys the framework itself reads. Unknown keys are left
  /// alone — apps are free to put their own values in here.
  ///
  /// Throws [ConfigException] listing everything that is wrong, rather
  /// than failing on the first problem.
  static void validate(Map<String, dynamic> config) {
    final problems = <String>[];

    final providers = config['providers'];
    if (providers == null) {
      problems.add(
        '"providers" is missing. It must be a List<ServiceProvider>, '
        'even if empty.',
      );
    } else if (providers is! List) {
      problems.add(
        '"providers" must be a List<ServiceProvider>, got '
        '${providers.runtimeType}.',
      );
    } else {
      for (var i = 0; i < providers.length; i++) {
        if (providers[i] is! ServiceProvider) {
          problems.add(
            '"providers[$i]" is a ${providers[i].runtimeType}, not a '
            'ServiceProvider.',
          );
        }
      }
    }

    final cors = config['cors'];
    if (cors != null && cors is! CORSConfig) {
      problems.add('"cors" must be a CORSConfig, got ${cors.runtimeType}.');
    }

    final csrfExcept = config['csrf_except'];
    if (csrfExcept != null && csrfExcept is! List) {
      problems.add(
        '"csrf_except" must be a List<String>, got '
        '${csrfExcept.runtimeType}.',
      );
    }

    final csrfProtectApi = config['csrf_protect_api'];
    if (csrfProtectApi != null && csrfProtectApi is! bool) {
      problems.add(
        '"csrf_protect_api" must be a bool, got '
        '${csrfProtectApi.runtimeType}.',
      );
    }

    if (problems.isNotEmpty) {
      throw ConfigException(
        'Invalid application config:\n  - ${problems.join('\n  - ')}',
      );
    }
  }
}

/// Thrown when the application config is missing a required key or holds
/// a value of the wrong type.
class ConfigException implements Exception {
  final String message;
  ConfigException(this.message);

  @override
  String toString() => 'ConfigException: $message';
}

/// Cross-origin resource sharing settings.
///
/// [origin] accepts a single origin, a `List` of origins, or `'*'`.
/// A list is matched against the request's `Origin` header and echoed
/// back on a match, with `Vary: Origin` set.
///
/// `'*'` cannot be combined with `credentials: true`; browsers reject
/// that pairing.
class CORSConfig {
  final bool enabled;
  final dynamic origin;
  final dynamic methods;
  final dynamic headers;
  final dynamic exposeHeaders;
  final bool? credentials;
  final num? maxAge;

  const CORSConfig({
    this.enabled = true,
    this.origin,
    this.methods,
    this.headers,
    this.exposeHeaders,
    this.credentials,
    this.maxAge,
  });
}
