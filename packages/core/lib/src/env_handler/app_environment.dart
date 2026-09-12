import '../../env.dart';

/// The deployment mode the app is running in, read from `APP_ENV`.
enum AppEnvironment {
  local,
  staging,
  production;

  /// Spellings accepted for each mode, so an app that already uses
  /// `APP_ENV=development` or `APP_ENV=prod` keeps working.
  static const Map<String, AppEnvironment> _aliases = {
    'local': local,
    'dev': local,
    'development': local,
    'test': local,
    'testing': local,
    'staging': staging,
    'stage': staging,
    'production': production,
    'prod': production,
  };

  /// Reads `APP_ENV`. An unset or unrecognised value resolves to
  /// [production] so a misconfigured deployment fails safe.
  static AppEnvironment current() {
    Env().load();
    final raw = env<String>('APP_ENV', 'production').trim().toLowerCase();
    return _aliases[raw] ?? AppEnvironment.production;
  }

  bool get isLocal => this == AppEnvironment.local;
  bool get isStaging => this == AppEnvironment.staging;
  bool get isProduction => this == AppEnvironment.production;

  /// Whether destructive commands must be confirmed with `--force` here.
  bool get isProtected => this != AppEnvironment.local;
}
