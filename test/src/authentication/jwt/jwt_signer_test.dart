import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:vania/src/authentication/token_handler/jwt/jwt_config.dart';
import 'package:vania/src/authentication/token_handler/jwt/jwt_signer.dart';

import 'jwt_signer_test.mocks.dart';

@GenerateMocks([JwtConfig])
void main() {
  group('JwtSigner', () {
    late JwtSigner jwtSigner;
    late JwtConfig config;

    setUp(() {
      config = MockJwtConfig();
      jwtSigner = JwtSigner(config);
    });

    test('createToken', () {
      // Arrange
      when(config.secretKey).thenReturn('secret_key');
      when(config.audience).thenReturn('audience');
      when(config.jwtId).thenReturn('jwt_id');
      when(config.issuer).thenReturn('issuer');
      when(config.subject).thenReturn('subject');

      final payload = {'id': 'user_id'};

      // Act
      Map<String, dynamic> result = jwtSigner.createToken(payload: payload);

      // Assert
      expect(result, isNotNull);
      expect(result['access_token'], isNotNull);
      expect(result['expires_in'], isNotNull);
    });
    test('createToken with refresh token', () {
      // Arrange
      when(config.secretKey).thenReturn('secret_key');
      when(config.audience).thenReturn('audience');
      when(config.jwtId).thenReturn('jwt_id');
      when(config.issuer).thenReturn('issuer');
      when(config.subject).thenReturn('subject');

      final payload = {'id': 'user_id'};

      // Act
      Map<String, dynamic> result =
          jwtSigner.createToken(payload: payload, withRefreshToken: true);

      // Assert
      expect(result, isNotNull);
      expect(result['access_token'], isNotNull);
      expect(result['refresh_token'], isNotNull);
      expect(result['expires_in'], isNotNull);
    });
  });
}
