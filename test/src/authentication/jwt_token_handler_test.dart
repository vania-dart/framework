import 'package:mockito/annotations.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:vania/src/authentication/token_handler/jwt/jwt_signer.dart';
import 'package:vania/src/authentication/token_handler/jwt/jwt_token_handler.dart';
import 'package:vania/src/authentication/token_handler/jwt/jwt_verifier.dart';

import 'jwt_token_handler_test.mocks.dart';

@GenerateMocks([JwtSigner, JwtVerifier])
void main() {
  group('JwtTokenHandler', () {
    late JwtTokenHandler tokenHandler;
    late JwtSigner signer;
    late JwtVerifier verifier;

    setUp(() {
      signer = MockJwtSigner();
      verifier = MockJwtVerifier();
      tokenHandler = JwtTokenHandler(signer, verifier);
    });

    test('createToken', () {
      final payload = {'id': 'user_id'};
      when(signer.createToken(
              payload: payload, guard: '', withRefreshToken: false))
          .thenReturn({'access_token': 'access_token', 'expires_in': 3600});

      final result = tokenHandler.createToken(payload);

      expect(result, isNotNull);
      expect(result['access_token'], equals('access_token'));
      expect(result['expires_in'], equals(3600));
    });

    test('verifyToken', () {
      final token = 'token';
      when(verifier.verify(token, '', 'access_token'))
          .thenReturn({'id': 'user_id'});

      final result = tokenHandler.verifyToken(token, '', 'access_token');

      expect(result, isNotNull);
      expect(result['id'], equals('user_id'));
    });

    test('refreshToken', () {
      final token = 'token';
      when(verifier.verify(token, '', 'refresh_token'))
          .thenReturn({'id': 'user_id'});
      when(signer.createToken(
              payload: {'id': 'user_id'}, guard: '', withRefreshToken: true))
          .thenReturn({
        'access_token': 'new_access_token',
        'refresh_token': 'new_refresh_token',
        'expires_in': 3600
      });

      final result = tokenHandler.refreshToken(token, '');

      expect(result, isNotNull);
      expect(result['access_token'], equals('new_access_token'));
      expect(result['refresh_token'], equals('new_refresh_token'));
      expect(result['expires_in'], equals(3600));
    });
  });
}
