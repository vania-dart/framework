import 'package:vania/src/env_handler/env_interface.dart';

class JwtConfig {
  final IEnv env;

  JwtConfig(this.env);

  String get secretKey {
    String key = env.get<String>('JWT_SECRET_KEY');
    return key.isEmpty ? env.get<String>('APP_KEY') : key;
  }

  String get audience => env.get<String>('JWT_AUDIENCE');
  String? get jwtId => env.get<String?>('JWT_ID');
  String? get issuer => env.get<String?>('JWT_ISSUER');
  String? get subject => env.get<String?>('JWT_SUBJECT');
}
