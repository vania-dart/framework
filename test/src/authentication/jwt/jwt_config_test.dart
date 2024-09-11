import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:vania/src/authentication/token_handler/jwt/jwt_config.dart';

import '../token_handler_test.mocks.dart';

void main() {
  group('JwtConfig Tests', () {
    late JwtConfig jwtConfig;
    late MockEnv env;

    setUp(() {
      env = MockEnv();
      jwtConfig = JwtConfig(env);
    });

    test('secretKey', () {
      when(env.get<String>('JWT_SECRET_KEY')).thenReturn('secret_key');
      when(env.get<String>('APP_KEY')).thenReturn('app_key');
      expect(jwtConfig.secretKey, equals('secret_key'));

      when(env.get<String>('JWT_SECRET_KEY')).thenReturn('');
      expect(jwtConfig.secretKey, equals('app_key'));
    });

    test('audience', () {
      when(env.get<String>('JWT_AUDIENCE')).thenReturn('audience');
      expect(jwtConfig.audience, equals('audience'));
    });

    test('jwtId', () {
      when(env.get<String?>('JWT_ID')).thenReturn('jwt_id');
      expect(jwtConfig.jwtId, equals('jwt_id'));
    });

    test('issuer', () {
      when(env.get<String?>('JWT_ISSUER')).thenReturn('issuer');
      expect(jwtConfig.issuer, equals('issuer'));
    });

    test('subject', () {
      when(env.get<String?>('JWT_SUBJECT')).thenReturn('subject');
      expect(jwtConfig.subject, equals('subject'));
    });

    // Further tests for other properties
  });
}
