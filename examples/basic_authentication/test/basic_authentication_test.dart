import 'package:test/test.dart';
import 'package:vania_auth/vania_auth.dart';

/// In-memory [UserProvider] so the auth flow can be exercised without a
/// database. Mirrors what `ModelUserProvider` does against the `users` table.
class InMemoryUserProvider implements UserProvider {
  final List<Map<String, dynamic>> _users = [];
  int _nextId = 1;

  @override
  String get idKey => 'id';

  @override
  Future<Map<String, dynamic>?> findById(dynamic id) async {
    for (final user in _users) {
      if (user['id'] == id) return Map<String, dynamic>.from(user);
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> findByEmail(String email) async {
    for (final user in _users) {
      if (user['email'] == email) return Map<String, dynamic>.from(user);
    }
    return null;
  }

  @override
  Future<bool> validatePassword(
    Map<String, dynamic> user,
    String plainPassword,
  ) async {
    return PasswordHasher().verify(plainPassword, user['password']);
  }

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final user = {'id': _nextId++, ...data};
    _users.add(user);
    return Map<String, dynamic>.from(user);
  }
}

/// In-memory [PersonalAccessTokenStore]; the counterpart to
/// `ModelPersonalAccessTokenStore`.
class InMemoryTokenStore implements PersonalAccessTokenStore {
  final Map<String, Map<String, dynamic>> _tokens = {};

  @override
  Future<void> create({
    required String name,
    required dynamic tokenableId,
    required String tokenHash,
    required Duration? expiresIn,
  }) async {
    _tokens[tokenHash] = {
      'name': name,
      'tokenable_id': tokenableId,
      'revoked': false,
    };
  }

  @override
  Future<bool> exists(String tokenHash) async => _tokens.containsKey(tokenHash);

  @override
  Future<void> markUsed(String tokenHash) async {
    _tokens[tokenHash]?['last_used_at'] = DateTime.now();
  }

  @override
  Future<void> revoke(String tokenHash) async {
    _tokens[tokenHash]?['revoked'] = true;
  }

  @override
  Future<void> revokeAll(dynamic userId) async {
    for (final entry in _tokens.values) {
      if (entry['tokenable_id'] == userId) entry['revoked'] = true;
    }
  }

  @override
  Future<void> revokeAllByName(String name) async {
    for (final entry in _tokens.values) {
      if (entry['name'] == name) entry['revoked'] = true;
    }
  }

  @override
  Future<bool> isRevoked(String tokenHash) async =>
      _tokens[tokenHash]?['revoked'] == true;

  @override
  Future<Map<String, dynamic>?> find(String tokenHash) async =>
      _tokens[tokenHash];
}

void main() {
  late InMemoryUserProvider users;
  late InMemoryTokenStore tokens;

  setUp(() {
    users = InMemoryUserProvider();
    tokens = InMemoryTokenStore();

    JwtService().configure(secretKey: 'test-secret-key-basic-auth');

    Auth().reset();
    Auth().configureGuard(
      'default',
      tokenStore: tokens,
      userProvider: users,
    );
  });

  // Mirrors AuthController.register.
  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
  ) async {
    final user = await users.create({
      'name': name,
      'email': email,
      'password': Auth().hash.make(password),
    });
    Auth().login(user);
    final token = await Auth().createToken(expiresIn: Duration(days: 30));
    return {'user': user, 'token': token['access_token']};
  }

  // Mirrors AuthController.login.
  Future<Map<String, dynamic>?> login(String email, String password) async {
    final user = await users.findByEmail(email);
    if (user == null || !Auth().hash.verify(password, user['password'])) {
      return null;
    }
    Auth().login(user);
    final token = await Auth().createToken(expiresIn: Duration(days: 30));
    return {'user': user, 'token': token['access_token']};
  }

  group('register', () {
    test('creates a user and returns an access token', () async {
      final result = await register('Alice', 'alice@example.com', 'password123');

      expect(result['user']['id'], 1);
      expect(result['user']['email'], 'alice@example.com');
      expect(result['token'], isA<String>());
      expect(result['token'], isNotEmpty);
    });

    test('stores the password hashed, never in plain text', () async {
      await register('Alice', 'alice@example.com', 'password123');

      final stored = await users.findByEmail('alice@example.com');
      expect(stored!['password'], isNot('password123'));
      expect(
        PasswordHasher().verify('password123', stored['password']),
        isTrue,
      );
    });

    test('issued token authenticates the user', () async {
      final result = await register('Alice', 'alice@example.com', 'password123');

      final ok = await Auth().check(result['token']);
      expect(ok, isTrue);
      expect(Auth().id, 1);
    });
  });

  group('login', () {
    setUp(() async {
      await register('Bob', 'bob@example.com', 'secret123');
      Auth().reset();
      Auth().configureGuard('default', tokenStore: tokens, userProvider: users);
    });

    test('succeeds with correct credentials', () async {
      final result = await login('bob@example.com', 'secret123');

      expect(result, isNotNull);
      expect(result!['token'], isNotEmpty);
    });

    test('fails with a wrong password', () async {
      final result = await login('bob@example.com', 'wrong-password');
      expect(result, isNull);
    });

    test('fails for an unknown email', () async {
      final result = await login('nobody@example.com', 'secret123');
      expect(result, isNull);
    });
  });

  group('protected access', () {
    test('a valid token resolves the current user', () async {
      final result = await register('Carol', 'carol@example.com', 'password123');

      expect(await Auth().check(result['token']), isTrue);
      expect(Auth().get('email'), 'carol@example.com');
    });

    test('rejects a garbage token', () async {
      await register('Carol', 'carol@example.com', 'password123');
      expect(
        () => Auth().check('not-a-real-token'),
        throwsA(isA<JwtAuthException>()),
      );
    });
  });

  group('logout', () {
    test('revoked token can no longer authenticate', () async {
      final result = await register('Dave', 'dave@example.com', 'password123');
      final token = result['token'] as String;

      expect(await Auth().check(token), isTrue);

      await Auth().revokeToken(token);

      expect(
        () => Auth().check(token),
        throwsA(isA<JwtAuthException>()),
      );
    });
  });
}
