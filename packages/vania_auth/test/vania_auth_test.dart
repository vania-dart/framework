import 'package:test/test.dart';
import 'package:vania_auth/vania_auth.dart';

void main() {
  group('PasswordHasher', () {
    late PasswordHasher hasher;

    setUp(() {
      hasher = PasswordHasher();
    });

    test('make generates hash with vania1 prefix', () {
      final hashed = hasher.make('password123');
      expect(hashed, startsWith('vania1\$'));
    });

    test('verify returns true for correct password', () {
      final hashed = hasher.make('password123');
      expect(hasher.verify('password123', hashed), isTrue);
    });

    test('verify returns false for wrong password', () {
      final hashed = hasher.make('password123');
      expect(hasher.verify('wrongpassword', hashed), isFalse);
    });

    test('make generates different hashes for same password', () {
      final hash1 = hasher.make('password123');
      final hash2 = hasher.make('password123');
      expect(hash1, isNot(equals(hash2)));
    });

    test('static check works', () {
      final hashed = PasswordHasher.makeStatic('test123');
      expect(PasswordHasher.check('test123', hashed), isTrue);
    });
  });

  group('TokenHasher', () {
    test('hash produces consistent MD5', () {
      final h1 = TokenHasher.hash('test-token');
      final h2 = TokenHasher.hash('test-token');
      expect(h1, equals(h2));
    });

    test('hash produces different values for different tokens', () {
      final h1 = TokenHasher.hash('token-1');
      final h2 = TokenHasher.hash('token-2');
      expect(h1, isNot(equals(h2)));
    });

    test('hashSha256 produces consistent SHA256', () {
      final h1 = TokenHasher.hashSha256('test-token');
      final h2 = TokenHasher.hashSha256('test-token');
      expect(h1, equals(h2));
    });
  });

  group('Gate', () {
    setUp(() {
      Gate().clear();
    });

    test('define and allows', () {
      Gate().define('canDelete', () => true);
      expect(Gate().allows('canDelete'), isTrue);
    });

    test('denies returns false when not defined', () {
      expect(Gate().denies('nonexistent'), isTrue);
    });

    test('has returns true when defined', () {
      Gate().define('canEdit', () => false);
      expect(Gate().has('canEdit'), isTrue);
    });

    test('forget removes ability', () {
      Gate().define('canView', () => true);
      Gate().forget('canView');
      expect(Gate().has('canView'), isFalse);
    });

    test('clear removes all abilities', () {
      Gate().define('a', () => true);
      Gate().define('b', () => true);
      Gate().clear();
      expect(Gate().has('a'), isFalse);
      expect(Gate().has('b'), isFalse);
    });
  });

  group('JwtService', () {
    setUp(() {
      JwtService().configure(
        secretKey: 'test-secret-key',
        audience: 'test-audience',
        issuer: 'test-issuer',
      );
    });

    test('createToken returns access_token and expires_in', () {
      final token = JwtService().createToken(
        payload: {'id': 1, 'email': 'test@test.com'},
        guard: 'default',
      );
      expect(token, contains('access_token'));
      expect(token, contains('expires_in'));
      expect(token['access_token'], isA<String>());
    });

    test('createToken with refresh token', () {
      final token = JwtService()
          .configure(secretKey: 'test-secret-key')
          .createToken(
            payload: {'id': 1},
            guard: 'default',
            withRefreshToken: true,
          );
      expect(token, contains('refresh_token'));
      expect(token['refresh_token'], isA<String>());
    });

    test('verify returns payload for valid token', () {
      final token = JwtService().createToken(
        payload: {'id': 1, 'name': 'test'},
        guard: 'default',
      );
      final payload = JwtService().verify(
        token['access_token'],
        'default',
        'access_token',
      );
      expect(payload['id'], equals(1));
    });

    test('verify throws for wrong guard', () {
      final token = JwtService().createToken(payload: {'id': 1}, guard: 'web');
      expect(
        () => JwtService().verify(token['access_token'], 'api', 'access_token'),
        throwsA(isA<JwtAuthException>()),
      );
    });

    test('verify throws for wrong token type', () {
      final token = JwtService().createToken(
        payload: {'id': 1},
        guard: 'default',
        withRefreshToken: true,
      );
      expect(
        () => JwtService().verify(
          token['access_token'],
          'default',
          'refresh_token',
        ),
        throwsA(isA<JwtAuthException>()),
      );
    });

    test('refreshToken generates new token pair', () {
      final original = JwtService().createToken(
        payload: {'id': 1},
        guard: 'default',
        withRefreshToken: true,
      );
      final refreshed = JwtService().refreshToken(
        original['refresh_token'],
        'default',
      );
      expect(refreshed, contains('access_token'));
      expect(refreshed, contains('refresh_token'));
      expect(refreshed['access_token'], isA<String>());
      expect(refreshed['refresh_token'], isA<String>());
      final payload = JwtService().verify(
        refreshed['access_token'],
        'default',
        'access_token',
      );
      expect(payload['id'], equals(1));
    });
  });

  group('Auth', () {
    late Auth auth;

    setUp(() {
      auth = Auth();
      auth.reset();
      JwtService().configure(secretKey: 'test-secret');
    });

    test('login sets user', () {
      auth.login({'id': 1, 'name': 'test'});
      expect(auth.currentUser['name'], equals('test'));
      expect(auth.loggedIn, isTrue);
    });

    test('logout clears user', () {
      auth.login({'id': 1});
      auth.logout();
      expect(auth.loggedIn, isFalse);
    });

    test('guard switches guard', () {
      auth.guard('admin').login({'id': 1, 'role': 'admin'});
      expect(auth.currentGuard, equals('admin'));
      expect(auth.currentUser['role'], equals('admin'));
    });

    test('multiple guards maintain separate users', () {
      auth.guard('web').login({'id': 1});
      auth.guard('api').login({'id': 2});

      auth.guard('web');
      expect(auth.id, equals(1));

      auth.guard('api');
      expect(auth.id, equals(2));
    });

    test('get returns specific field', () {
      auth.login({'id': 1, 'email': 'test@test.com'});
      expect(auth.get('email'), equals('test@test.com'));
    });

    test('clearAll resets everything', () {
      auth.guard('web').login({'id': 1});
      auth.guard('api').login({'id': 2});
      auth.clearAll();
      expect(auth.loggedIn, isFalse);
    });

    test('guard-specific stores are isolated while creating tokens', () async {
      final webStore = _MemoryTokenStore();
      final adminStore = _MemoryTokenStore();
      auth.configureGuard('web', tokenStore: webStore);
      auth.configureGuard('admin', tokenStore: adminStore);

      auth.guard('web').login({'id': 1});
      await auth.createToken();

      auth.guard('admin').login({'id': 2});
      await auth.createToken();

      expect(webStore.created.single['tokenable_id'], equals(1));
      expect(adminStore.created.single['tokenable_id'], equals(2));
    });

    test('check snapshots guard before awaits', () async {
      final webStore = _MemoryTokenStore();
      final adminStore = _MemoryTokenStore();
      final webProvider = _DelayedUserProvider({
        'id': 1,
        'email': 'web@test.dev',
      });
      final adminProvider = _DelayedUserProvider({
        'id': 2,
        'email': 'admin@test.dev',
      });
      auth.configureGuard(
        'web',
        tokenStore: webStore,
        userProvider: webProvider,
      );
      auth.configureGuard(
        'admin',
        tokenStore: adminStore,
        userProvider: adminProvider,
      );

      auth.guard('web').login({'id': 1});
      final webToken = await auth.createToken();
      auth.guard('admin').login({'id': 2});
      final adminToken = await auth.createToken();
      auth.clearAll();

      final webCheck = auth.guard('web').check(webToken['access_token']);
      final adminCheck = auth.guard('admin').check(adminToken['access_token']);

      expect(await Future.wait([webCheck, adminCheck]), equals([true, true]));
      expect(auth.guard('web').currentUser['email'], equals('web@test.dev'));
      expect(
        auth.guard('admin').currentUser['email'],
        equals('admin@test.dev'),
      );
    });
  });
}

class _MemoryTokenStore implements PersonalAccessTokenStore {
  final List<Map<String, dynamic>> created = [];
  final Set<String> revoked = {};

  @override
  Future<void> create({
    required String name,
    required tokenableId,
    required String tokenHash,
    required Duration? expiresIn,
  }) async {
    created.add({
      'name': name,
      'tokenable_id': tokenableId,
      'token': tokenHash,
      'expires_at': expiresIn == null ? null : DateTime.now().add(expiresIn),
    });
  }

  @override
  Future<bool> exists(String tokenHash) async {
    return created.any((token) => token['token'] == tokenHash);
  }

  @override
  Future<Map<String, dynamic>?> find(String tokenHash) async {
    for (final token in created) {
      if (token['token'] == tokenHash) return token;
    }
    return null;
  }

  @override
  Future<bool> isRevoked(String tokenHash) async {
    return revoked.contains(tokenHash);
  }

  @override
  Future<void> markUsed(String tokenHash) async {
    final token = await find(tokenHash);
    token?['last_used_at'] = DateTime.now();
  }

  @override
  Future<void> revoke(String tokenHash) async {
    revoked.add(tokenHash);
  }

  @override
  Future<void> revokeAll(userId) async {}

  @override
  Future<void> revokeAllByName(String name) async {}
}

class _DelayedUserProvider implements UserProvider {
  final Map<String, dynamic> user;

  _DelayedUserProvider(this.user);

  @override
  String get idKey => 'id';

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    return data;
  }

  @override
  Future<Map<String, dynamic>?> findByEmail(String email) async {
    await Future<void>.delayed(Duration.zero);
    return user['email'] == email ? user : null;
  }

  @override
  Future<Map<String, dynamic>?> findById(id) async {
    await Future<void>.delayed(Duration.zero);
    return user['id'] == id ? user : null;
  }

  @override
  Future<bool> validatePassword(
    Map<String, dynamic> user,
    String plainPassword,
  ) async {
    return true;
  }
}
