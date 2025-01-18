import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:vania/src/exception/invalid_argument_exception.dart';
import 'package:vania/src/exception/unauthenticated.dart';
import 'package:vania/vania.dart';

import 'model/personal_access_token.dart';

class Auth {
  static final Auth _singleton = Auth._internal();
  factory Auth() => _singleton;
  Auth._internal();

  String _userGuard = 'default';

  bool _loggedIn = false;

  String _currentToken = '';

  final Map<String, dynamic> _user = {};

  bool get loggedIn => _loggedIn;

  Map<String, dynamic>? user() => _user[_userGuard];

  dynamic id() => _user[_userGuard]['id'] ?? _user[_userGuard]['_id'];

  dynamic get(String filed) => _user[_userGuard][filed];

  /// Sets the authentication guard to the specified guard name.
  ///
  /// This method changes the current user guard to the specified guard, which
  /// determines the user provider and authentication logic to use. If the
  /// specified guard is not defined in the configuration, an
  /// [InvalidArgumentException] is thrown.
  ///
  /// Returns the current instance of the `Auth` class.
  ///
  /// Throws:
  /// - [InvalidArgumentException] if the specified guard is not defined.
  ///
  Auth guard(String guard) {
    if (Config().get('auth')['guards'][guard] == null) {
      throw InvalidArgumentException('Auth guard [$guard] is not defined.');
    }

    _userGuard = guard;
    return this;
  }

  /// Set the current user from a given user object.
  ///
  /// The object is expected to contain at least the `id` key.
  ///
  /// The user object will be stored in the `_user` map with the key being the
  /// current guard.
  ///
  /// Returns the current instance of the `Auth` class.
  Auth login(Map<String, dynamic> user) {
    _user[_userGuard] = user;
    _updateSession();
    return this;
  }

  Future<void> logout() async {
    await setSession('logged_in', false);
    await setSession('auth_user', null);
    await setSession('auth_guard', null);
    _loggedIn = false;
    if (_currentToken.isNotEmpty) {
      try {
        await PersonalAccessTokens()
            .query()
            .where('token', '=', md5.convert(utf8.encode(_currentToken)))
            .update({'deleted_at': DateTime.now()});
      } catch (_) {}
    }
  }

  /// Updates the current session with the given user and guard.
  ///
  /// The function sets the `logged_in` session key to true, and updates the
  /// `auth_user` and `auth_guard` session keys if they are not already set or
  /// have changed. The function also sets the `_isAuthorized` flag to true.
  ///
  /// The session is only updated if the user and guard have changed, and the
  /// function does not return anything.
  Future<void> _updateSession() async {
    await setSession('logged_in', true);

    if (await getSession<Map?>('auth_user') != _user) {
      await setSession('auth_user', _user);
    }

    if (await getSession<String?>('auth_guard') != _userGuard) {
      await setSession('auth_guard', _userGuard);
    }

    _loggedIn = true;
  }

  /// Create new token for the given user.
  ///
  /// The token created is a JWT token that contains the user's ID and the
  /// guard's name. The token is then signed with the secret key from the
  /// environment variable `JWT_SECRET_KEY`.
  ///
  /// If `withRefreshToken` is true, a refresh token is also created and
  /// returned in the `refresh_token` key of the map.
  ///
  /// If `customToken` is true, the token is not stored in the database and
  /// is returned as is.
  ///
  /// The `expiresIn` parameter is the duration after which the token will
  /// expire. If not provided, the token will expire after 1 hour.
  ///
  /// Returns a map containing the following keys:
  ///
  /// * `access_token`: the JWT token
  /// * `refresh_token`: the refresh token if `withRefreshToken` is true
  /// * `expires_in`: the duration after which the token will expire in seconds
  Future<Map<String, dynamic>> createToken({
    Duration? expiresIn,
    bool withRefreshToken = false,
    bool customToken = false,
  }) async {
    Map<String, dynamic> token = HasApiTokens()
        .setPayload(_user[_userGuard])
        .createToken(_userGuard, expiresIn, withRefreshToken);

    if (!customToken) {
      await PersonalAccessTokens().query().insert({
        'name': _userGuard,
        'tokenable_id': _user[_userGuard]['id'],
        'token': md5.convert(utf8.encode(token['access_token'])).toString(),
        'created_at': DateTime.now(),
      });
    }

    return token;
  }

  /// Create a new token by given refresh token.
  //
  /// The given token must be a valid refresh token.
  //
  /// The `expiresIn` parameter is the duration after which the token will
  /// expire. If not provided, the token will expire after 1 hour.
  //
  /// The `customToken` parameter determines if the token should be stored in
  /// the database or not. If `customToken` is true, the token is not stored
  /// in the database.
  //
  /// Returns a map containing the following keys:
  //
  /// * `access_token`: the JWT token
  /// * `refresh_token`: the refresh token
  /// * `expires_in`: the duration after which the token will expire in seconds
  Future<Map<String, dynamic>> createTokenByRefreshToken(
    String token, {
    Duration? expiresIn,
    bool customToken = false,
  }) async {
    final newToken = HasApiTokens().refreshToken(
      token.replaceFirst('Bearer ', ''),
      _userGuard,
      expiresIn,
    );

    if (!customToken) {
      Map<String, dynamic> payload = HasApiTokens().verify(
          token.replaceFirst('Bearer ', ''), _userGuard, 'refresh_token');

      Model? authenticatable =
          Config().get('auth')['guards'][_userGuard]['provider'];

      if (authenticatable == null) {
        throw InvalidArgumentException('Authenticatable class not found');
      }

      Map? user =
          await authenticatable.query().where('id', '=', payload['id']).first();

      if (user == null) {
        throw Unauthenticated(message: 'Invalid token');
      }

      _user[_userGuard] = user;
      await PersonalAccessTokens().query().insert({
        'name': _userGuard,
        'tokenable_id': user['id'],
        'token': md5.convert(utf8.encode(newToken['access_token'])),
        'created_at': DateTime.now(),
      });
    }

    return newToken;
  }

  /// Delete all the tokens for the user that is currently logged in.
  ///
  /// This is useful when a user logs out and you want to delete all of their
  /// tokens.
  ///
  /// Returns true if the operation was successful.
  Future<bool> deleteTokens() async {
    await PersonalAccessTokens()
        .query()
        .where('tokenable_id', '=', _user[_userGuard]['id'])
        .update({'deleted_at': DateTime.now()});

    return true;
  }

  /// Delete the current token for the user that is currently logged in.
  ///
  /// This function marks the current token as deleted by setting the `deleted_at`
  /// field to the current time in the database. This operation helps to effectively
  /// invalidate the token.
  ///
  /// Returns a Future that resolves to true if the operation was successful.
  ///
  Future<bool> deleteCurrentToken() async {
    await PersonalAccessTokens()
        .query()
        .where('token', '=', md5.convert(utf8.encode(_currentToken)))
        .update({'deleted_at': DateTime.now()});
    return true;
  }

  /// Validates and checks the provided token for authentication.
  ///
  /// This function verifies the provided JWT access token and checks its validity
  /// against stored personal access tokens. If the token is valid, it updates the
  /// token's last used timestamp and sets the current user context, marking them
  /// as authorized.
  ///
  /// The function handles both custom and stored tokens. For custom tokens, it
  /// sets the user payload directly. For stored tokens, it ensures the token exists
  /// and is not marked as deleted, then retrieves the associated user.
  ///
  /// Throws:
  /// - [Unauthenticated] if the token is invalid or not found.
  /// - [InvalidArgumentException] if the authenticatable provider class is not found.
  ///
  /// Returns a Future that resolves to true if the token is valid and the user is successfully authenticated.
  ///
  Future<bool> check(
    String token, {
    Map<String, dynamic>? user,
    bool isCustomToken = false,
  }) async {
    Map<String, dynamic> payload = HasApiTokens()
        .verify(token.replaceFirst('Bearer ', ''), _userGuard, 'access_token');

    if (isCustomToken) {
      _user[_userGuard] = payload;
      _loggedIn = true;
      _currentToken = token;
      return true;
    } else {
      Map<String, dynamic>? exists = await PersonalAccessTokens()
          .query()
          .where('token', '=', md5.convert(utf8.encode(token)))
          .whereNull('deleted_at')
          .first(['id']);
      // Throw 401 Error if token not found
      if (exists == null) {
        throw Unauthenticated(message: 'Invalid token');
      }

      await PersonalAccessTokens()
          .query()
          .where('token', '=', md5.convert(utf8.encode(token)))
          .update({'last_used_at': DateTime.now()});

      if (user == null) {
        Model? authenticatable =
            Config().get('auth')['guards'][_userGuard]['provider'];

        if (authenticatable == null) {
          throw InvalidArgumentException('Authenticatable class not found');
        }
        user = await authenticatable
            .query()
            .where('id', '=', payload['id'])
            .first();
      }

      if (user != null) {
        _user[_userGuard] = user;
        _loggedIn = true;
        _currentToken = token;
        return true;
      } else {
        throw Unauthenticated(message: 'Invalid token');
      }
    }
  }
}
