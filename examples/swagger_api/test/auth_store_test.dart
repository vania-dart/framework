import 'package:test/test.dart';
import 'package:swagger_api/features/auth/auth_store.dart';

void main() {
  group('AuthStore', () {
    late AuthStore store;

    setUp(() {
      store = AuthStore();
    });

    test('login with the demo credentials returns a token', () {
      final token = store.login('demo', 'password');
      expect(token, isNotNull);
      expect(token, isNotEmpty);
    });

    test('login with a wrong password returns null', () {
      expect(store.login('demo', 'nope'), isNull);
    });

    test('login for an unknown user returns null', () {
      expect(store.login('ghost', 'password'), isNull);
    });

    test('a minted token resolves back to its user', () {
      final token = store.login('demo', 'password')!;
      expect(store.userFor(token), 'demo');
    });

    test('an unknown token resolves to null', () {
      expect(store.userFor('not-a-token'), isNull);
    });
  });
}
