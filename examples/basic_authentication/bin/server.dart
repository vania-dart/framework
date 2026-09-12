import 'package:vania/vania.dart';
import 'package:vania_mysql/vania_mysql.dart';
import 'package:vania_auth/vania_auth.dart';
import 'package:basic_authentication/config/app.dart';
import 'package:basic_authentication/app/models/user.dart';
import 'package:basic_authentication/app/models/personal_access_token.dart';

void main(List<String> arguments) async {
  registerMySqlDriver();

  await AuthServiceProvider().register(
    jwtSecretKey: env('APP_KEY'),
    tokenStore: ModelPersonalAccessTokenStore(
      model: PersonalAccessToken(),
    ),
    userProvider: ModelUserProvider(model: User()),
  );

  await Application().initialize(config: config);
}
