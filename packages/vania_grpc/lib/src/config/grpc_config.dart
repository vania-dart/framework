import 'dart:io';

import 'package:grpc/grpc.dart';
import 'package:vania/foundation.dart' show Config, env;

class GrpcConfig {
  const GrpcConfig({
    required this.host,
    required this.port,
    this.enabled = true,
    this.autoStart = false,
    this.secure = false,
    this.certificatePath,
    this.certificatePassword,
    this.privateKeyPath,
    this.privateKeyPassword,
    this.backlog = 0,
    this.shared = false,
    this.v6Only = false,
    this.requestClientCertificate = false,
    this.requireClientCertificate = false,
    this.healthEnabled = true,
    this.keepAlive = const ServerKeepAliveOptions(),
  });

  final String host;
  final int port;
  final bool enabled;
  final bool autoStart;
  final bool secure;
  final String? certificatePath;
  final String? certificatePassword;
  final String? privateKeyPath;
  final String? privateKeyPassword;
  final int backlog;
  final bool shared;
  final bool v6Only;
  final bool requestClientCertificate;
  final bool requireClientCertificate;
  final bool healthEnabled;
  final ServerKeepAliveOptions keepAlive;

  factory GrpcConfig.fromApplication() {
    final config = Config().get('grpc');
    if (config is Map<String, dynamic>) return GrpcConfig.fromMap(config);
    return GrpcConfig.fromEnv();
  }

  factory GrpcConfig.fromEnv() {
    return GrpcConfig(
      host: env<String>('GRPC_HOST', InternetAddress.anyIPv4.address),
      port: env<int>('GRPC_PORT', 50051),
      enabled: env<bool>('GRPC_ENABLED', true),
      autoStart: env<bool>('GRPC_AUTOSTART', false),
      secure: env<bool>('GRPC_SECURE', false),
      certificatePath: env<String?>('GRPC_CERTIFICATE'),
      certificatePassword: env<String?>('GRPC_CERTIFICATE_PASSWORD'),
      privateKeyPath: env<String?>('GRPC_PRIVATE_KEY'),
      privateKeyPassword: env<String?>('GRPC_PRIVATE_KEY_PASSWORD'),
      backlog: env<int>('GRPC_BACKLOG', 0),
      shared: env<bool>('GRPC_SHARED', false),
      v6Only: env<bool>('GRPC_V6_ONLY', false),
      requestClientCertificate: env<bool>(
        'GRPC_REQUEST_CLIENT_CERTIFICATE',
        false,
      ),
      requireClientCertificate: env<bool>(
        'GRPC_REQUIRE_CLIENT_CERTIFICATE',
        false,
      ),
      healthEnabled: env<bool>('GRPC_HEALTH_ENABLED', true),
      keepAlive: ServerKeepAliveOptions(
        maxBadPings: env<int?>('GRPC_MAX_BAD_PINGS', 2),
        minIntervalBetweenPingsWithoutData: Duration(
          seconds: env<int>('GRPC_MIN_PING_INTERVAL_SECONDS', 300),
        ),
      ),
    );
  }

  factory GrpcConfig.fromMap(Map<String, dynamic> config) {
    return GrpcConfig(
      host: config['host']?.toString() ?? InternetAddress.anyIPv4.address,
      port: _int(config['port'], 50051),
      enabled: _bool(config['enabled'], true),
      autoStart: _bool(config['auto_start'] ?? config['autoStart'], false),
      secure: _bool(config['secure'], false),
      certificatePath: config['certificate']?.toString(),
      certificatePassword: config['certificate_password']?.toString(),
      privateKeyPath: config['private_key']?.toString(),
      privateKeyPassword: config['private_key_password']?.toString(),
      backlog: _int(config['backlog'], 0),
      shared: _bool(config['shared'], false),
      v6Only: _bool(config['v6_only'] ?? config['v6Only'], false),
      requestClientCertificate: _bool(
        config['request_client_certificate'],
        false,
      ),
      requireClientCertificate: _bool(
        config['require_client_certificate'],
        false,
      ),
      healthEnabled: _bool(config['health'] ?? config['health_enabled'], true),
      keepAlive: ServerKeepAliveOptions(
        maxBadPings: _nullableInt(config['max_bad_pings']) ?? 2,
        minIntervalBetweenPingsWithoutData: Duration(
          seconds: _int(config['min_ping_interval_seconds'], 300),
        ),
      ),
    );
  }

  ServerCredentials? credentials() {
    if (!secure) return null;
    return ServerTlsCredentials(
      certificate: _read(certificatePath),
      certificatePassword: certificatePassword,
      privateKey: _read(privateKeyPath),
      privateKeyPassword: privateKeyPassword,
    );
  }

  static bool _bool(dynamic value, bool fallback) {
    if (value == null) return fallback;
    if (value is bool) return value;
    return value.toString().toLowerCase() == 'true';
  }

  static int _int(dynamic value, int fallback) {
    return int.tryParse('${value ?? ''}') ?? fallback;
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    return int.tryParse('$value');
  }

  static List<int>? _read(String? path) {
    if (path == null || path.isEmpty) return null;
    return File(path).readAsBytesSync();
  }
}
