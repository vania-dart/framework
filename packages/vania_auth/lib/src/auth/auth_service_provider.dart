import 'package:vania/http/request.dart' show setRequestUserResolver;
import 'package:vania/vania.dart' show PersonalAccessTokenStore;

import '../auth/auth.dart';
import '../contracts/user_provider.dart';
import '../jwt/jwt_service.dart';

class AuthServiceProvider {
  static final AuthServiceProvider _instance = AuthServiceProvider._internal();
  factory AuthServiceProvider() => _instance;
  AuthServiceProvider._internal();

  Future<void> register({
    required String jwtSecretKey,
    String? jwtAudience,
    String? jwtIssuer,
    String? jwtId,
    String? jwtSubject,
    String guard = 'default',
    PersonalAccessTokenStore? tokenStore,
    UserProvider? userProvider,
    Map<String, AuthGuardConfig> guards = const {},
  }) async {
    JwtService().configure(
      secretKey: jwtSecretKey,
      audience: jwtAudience,
      issuer: jwtIssuer,
      jwtId: jwtId,
      subject: jwtSubject,
    );

    if (tokenStore != null) {
      Auth().setTokenStore(tokenStore, guard: guard);
    }

    if (userProvider != null) {
      Auth().setUserProvider(userProvider, guard: guard);
    }

    for (final entry in guards.entries) {
      Auth().configureGuard(
        entry.key,
        tokenStore: entry.value.tokenStore,
        userProvider: entry.value.userProvider,
      );
    }

    // Wire `Request.user` to read from the vania_auth Auth singleton so
    // `req.user` keeps working (throttle_test relies on this, and app
    // controllers routinely access it).
    setRequestUserResolver(() {
      if (!Auth().loggedIn) return null;
      return Auth().currentUser;
    });
  }
}
