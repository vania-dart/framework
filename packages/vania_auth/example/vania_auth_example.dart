import 'package:vania_auth/vania_auth.dart';

void main() async {
  JwtService().configure(
    secretKey: 'your-secret-key-here',
    audience: 'your-app',
    issuer: 'your-app',
  );

  final hasher = PasswordHasher();
  final hashed = hasher.make('my-password');
  print('Hashed: $hashed');
  print('Verify: ${hasher.verify('my-password', hashed)}');

  final token = JwtService().createToken(
    payload: {'id': 1, 'email': 'user@example.com'},
    guard: 'web',
    withRefreshToken: true,
  );
  print('Access Token: ${token['access_token']}');
  print('Refresh Token: ${token['refresh_token']}');

  final payload = JwtService().verify(
    token['access_token'],
    'web',
    'access_token',
  );
  print('Payload: $payload');
}
