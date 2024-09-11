import 'package:mockito/annotations.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:vania/src/authentication/token_handler/token_handler.dart';
import 'package:vania/src/authentication/user_repository.dart';
import 'package:vania/src/exception/unauthenticated.dart';
import 'package:vania/vania.dart';

import 'authentication_manager_test.mocks.dart';


@GenerateMocks([TokenHandler, UserRepository, Config])
void main() {
  group('AuthenticationManagerImpl', () {
    late AuthenticationManagerImpl authManager;
    late MockTokenHandler mockTokenHandler;
    late MockUserRepository mockUserRepository;
    late MockConfig mockConfig;

    setUp(() {
      mockTokenHandler = MockTokenHandler();
      mockUserRepository = MockUserRepository();
      mockConfig = MockConfig();
      authManager = AuthenticationManagerImpl(mockConfig,
          tokenHandler: mockTokenHandler, userRepository: mockUserRepository);
    });

    test('guard method should return instance of AuthenticationManagerImpl',
        () {
      final result = authManager.guard('default');
      expect(result, isA<AuthenticationManagerImpl>());
    });

    test('login method should return instance of AuthenticationManagerImpl',
        () {
      final result = authManager.login({'id': '123'});
      expect(result, isA<AuthenticationManagerImpl>());
    });

    test('isAuthorized getter should return false initially', () {
      final result = authManager.isAuthorized;
      expect(result, false);
    });

    test('check method should return true when isCustomToken is false but user is exist', () async {
      when(mockTokenHandler.verify(any, any, any)).thenReturn({'id': '123'});
      when(mockUserRepository.findUserByToken(any))
          .thenAnswer((_) async => {'id': '123'});
      when(mockConfig.get(any)).thenReturn({'provider': Model()});

      final result = await authManager.check('validToken', isCustomToken: true);
      expect(result, true);
    });
    test('check method should return true when token is valid', () async {
      when(mockTokenHandler.verify(any, any, any)).thenReturn({'id': '123'});
      when(mockUserRepository.findUserByToken(any))
          .thenAnswer((_) async => {'id': '123'});
      when(mockConfig.get(any)).thenReturn({'provider': Model()});

      final result = await authManager.check('validToken', isCustomToken: false, user: {'id': '123'});
      expect(result, true);
    });

    test('check method should throw Unauthenticated when token is invalid',
        () async {
      when(mockTokenHandler.verify(any, any, any)).thenReturn({'id': '123'});
      when(mockUserRepository.findUserByToken(any))
          .thenAnswer((_) async => null);
      when(mockConfig.get(any)).thenReturn({'provider': Model()});

      expect(() async => await authManager.check('invalidToken'),
          throwsA(isA<Unauthenticated>()));
    });

    // Add more tests for other methods like createToken, createTokenByRefreshToken, deleteTokens, deleteCurrentToken
  });
}
