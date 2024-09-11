import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:vania/src/authentication/authentication_manager.dart';
import 'package:vania/src/exception/unauthenticated.dart';
import 'package:vania/vania.dart';

import 'authenticate_test.mocks.dart';

@GenerateMocks([AuthenticationManager, Request])
void main() {
  group('Authenticate', () {
    late Authenticate authenticate;
    late MockAuthenticationManager mockAuthManager;
    late MockRequest mockRequest;

    setUp(() {
      mockAuthManager = MockAuthenticationManager();
      mockRequest = MockRequest();
      authenticate = Authenticate(auth: mockAuthManager);
    });

    test('handle method should not throw when token is valid', () async {
      when(mockRequest.header('authorization')).thenReturn('Bearer validToken');
      when(mockAuthManager.check(any)).thenAnswer((_) async => true);

      await authenticate.handle(mockRequest);
    });

    test('handle method should throw Unauthenticated when token is expired',
        () async {
      when(mockRequest.header('authorization'))
          .thenReturn('Bearer expiredToken');
      when(mockAuthManager.check(any)).thenThrow(JWTExpiredException());

      expect(() async => await authenticate.handle(mockRequest),
          throwsA(isA<Unauthenticated>()));
    });

    // Add more tests for different scenarios
  });
}
