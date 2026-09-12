import 'package:vania_auth/vania_auth.dart';

import 'model/personal_access_token.dart';

class OrmPersonalAccessTokenStore extends ModelPersonalAccessTokenStore {
  OrmPersonalAccessTokenStore()
    : super(
        model: PersonalAccessToken(),
        columns: const TokenStoreColumns(primaryKey: '_id'),
      );
}
