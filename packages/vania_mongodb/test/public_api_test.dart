// The compliance checks read `getTable` from outside the class on purpose.
// ignore_for_file: invalid_use_of_protected_member
import 'package:test/test.dart';
import 'package:vania_mongodb/vania_mongodb.dart';

class PublicApiUser extends Model {
  @override
  List<String> get guarded => ['_id'];
}

void main() {
  test('builds MongoDB config from uri', () {
    final config = MongoConfig.fromMap({
      'uri': 'mongodb://localhost:27017/app',
    });

    expect(config.uri, 'mongodb://localhost:27017/app');
  });

  test('builds MongoDB selectors with expressive where methods', () {
    final selector = MongoQueryBuilderImpl()
        .whereEqualTo('email', 'a@example.com')
        .whereIn('role', ['admin', 'owner'])
        .whereNull('deleted_at')
        .toSelector();

    expect(selector, {
      r'$and': [
        {'email': 'a@example.com'},
        {
          'role': {
            r'$in': ['admin', 'owner'],
          },
        },
        {'deleted_at': null},
      ],
    });
  });

  test('exports model and auth store APIs', () {
    final model = PublicApiUser();

    expect(model.getTable, 'public_api_users');
    expect(OrmPersonalAccessTokenStore(), isA<OrmPersonalAccessTokenStore>());
    expect(PersonalAccessToken(), isA<Model>());
  });
}
