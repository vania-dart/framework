import 'dart:io';

import 'package:grpc/grpc.dart';
import 'package:vania/foundation.dart' show env;

class GrpcClientConfig {
  const GrpcClientConfig({
    required this.host,
    required this.port,
    this.secure = false,
    this.authority,
    this.certificatePath,
    this.certificatePassword,
    this.connectTimeout,
    this.idleTimeout = const Duration(minutes: 5),
    this.userAgent = 'vania-grpc',
  });

  final String host;
  final int port;
  final bool secure;
  final String? authority;
  final String? certificatePath;
  final String? certificatePassword;
  final Duration? connectTimeout;
  final Duration? idleTimeout;
  final String userAgent;

  factory GrpcClientConfig.fromEnv({String prefix = 'GRPC_CLIENT'}) {
    return GrpcClientConfig(
      host: env<String>('${prefix}_HOST', '127.0.0.1'),
      port: env<int>('${prefix}_PORT', 50051),
      secure: env<bool>('${prefix}_SECURE', false),
      authority: env<String?>('${prefix}_AUTHORITY'),
      certificatePath: env<String?>('${prefix}_CERTIFICATE'),
      certificatePassword: env<String?>('${prefix}_CERTIFICATE_PASSWORD'),
      connectTimeout: Duration(
        seconds: env<int>('${prefix}_CONNECT_TIMEOUT_SECONDS', 10),
      ),
      idleTimeout: Duration(
        seconds: env<int>('${prefix}_IDLE_TIMEOUT_SECONDS', 300),
      ),
      userAgent: env<String>('${prefix}_USER_AGENT', 'vania-grpc'),
    );
  }
}

class GrpcClientFactory {
  const GrpcClientFactory._();

  static ClientChannel channel(GrpcClientConfig config) {
    return ClientChannel(
      config.host,
      port: config.port,
      options: ChannelOptions(
        credentials: _credentials(config),
        connectTimeout: config.connectTimeout,
        idleTimeout: config.idleTimeout,
        userAgent: config.userAgent,
      ),
    );
  }

  static ClientChannel insecure(String host, {int port = 50051}) {
    return channel(GrpcClientConfig(host: host, port: port));
  }

  static ClientChannel secure(
    String host, {
    int port = 443,
    String? authority,
    String? certificatePath,
  }) {
    return channel(
      GrpcClientConfig(
        host: host,
        port: port,
        secure: true,
        authority: authority,
        certificatePath: certificatePath,
      ),
    );
  }

  static ChannelCredentials _credentials(GrpcClientConfig config) {
    if (!config.secure) {
      return ChannelCredentials.insecure(authority: config.authority);
    }
    return ChannelCredentials.secure(
      certificates: _read(config.certificatePath),
      password: config.certificatePassword,
      authority: config.authority,
    );
  }

  static List<int>? _read(String? path) {
    if (path == null || path.isEmpty) return null;
    return File(path).readAsBytesSync();
  }
}
