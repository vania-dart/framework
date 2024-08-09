import 'package:mockito/annotations.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:vania/src/exception/unauthenticated.dart';
import 'package:vania/vania.dart';

import 'token_handler_test.mocks.dart';

@GenerateMocks([Env])
void main() {
  group('HasApiTokens Tests', () {
    late TokenHandler tokens;
    late MockEnv mockEnv;

    setUp(() {
      mockEnv = MockEnv();
      mockEnv.env = {
        'APP_KEY': 'app_key',
        'PORT': '8080',
        'JWT_SECRET_KEY': 'secret',
        'JWT_AUDIENCE': 'audience',
        'JWT_ISSUER': 'issuer',
        'FEATURE_ENABLED': 'true'
      };
      tokens = TokenHandler();
      // Mock environment variable    
    });

    test('Create token returns valid structure', () {
      final result = tokens.createToken();
      expect(result, contains('access_token'));
      expect(result['access_token'], isNotNull);
    });

    test('Refresh token returns new token with refresh', () {
      final oldToken = tokens.createToken('', null, true);
      final refreshToken = oldToken['refresh_token'];
      final newToken = tokens.refreshToken(refreshToken!);
      expect(newToken, contains('access_token'));
      expect(newToken['access_token'], isNot(equals(oldToken['access_token'])));
    });

    test('Verify throws Unauthenticated for invalid token type', () {
      expect(() => tokens.verify('dummy_token', 'guard', 'access_token'),
          throwsA(isA<Unauthenticated>()));
    });
  });
}
