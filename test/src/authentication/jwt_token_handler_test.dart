import 'package:mockito/annotations.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:vania/src/authentication/jwt_token_handler.dart';
import 'package:vania/src/exception/unauthenticated.dart';
import 'package:vania/vania.dart';

import 'token_handler_test.mocks.dart';

@GenerateMocks([Env])
void main() {
  late MockEnv mockEnv;
  late JwtTokenHandler tokenHandler;
  group('TokenHandler', () {
    setUp(() {
      mockEnv = MockEnv();
      tokenHandler = JwtTokenHandler(mockEnv);
      when(mockEnv.get<String>('JWT_SECRET_KEY')).thenReturn('supersecret');
      when(mockEnv.get<String>('APP_KEY')).thenReturn('fallbacksecret');
      when(mockEnv.get<String>('JWT_AUDIENCE')).thenReturn('audience');
      when(mockEnv.get<String?>('JWT_ID')).thenReturn('jwtid');
      when(mockEnv.get<String?>('JWT_ISSUER')).thenReturn('issuer');
      when(mockEnv.get<String?>('JWT_SUBJECT')).thenReturn('subject');
    });

    test('createToken generates access token correctly', () {
      var payload = tokenHandler.createToken();
      expect(payload, contains('access_token'));
      expect(payload, contains('expires_in'));
    });

    test('refreshToken generates a new token with refresh token', () {
      // Ensure the secret key and guard are correct
      when(mockEnv.get<String?>('JWT_AUDIENCE')).thenReturn(null);
      when(mockEnv.get<String?>('JWT_ID')).thenReturn(null);
      when(mockEnv.get<String?>('JWT_ISSUER')).thenReturn(null);
      when(mockEnv.get<String?>('JWT_SUBJECT')).thenReturn(null);

      var payload = tokenHandler.createToken(withRefreshToken: true);
      final String refreshToken = payload['refresh_token'];
      var newToken = tokenHandler.refreshToken(refreshToken);
      expect(newToken, contains('access_token'));
      expect(newToken, contains('refresh_token'));
    });

    test('verify throws Unauthenticated when token type is incorrect', () {
      expect(() => tokenHandler.verify('invalidtoken', '', 'access_token'),
          throwsA(isA<Unauthenticated>()));
    });
  });
}
