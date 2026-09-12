import 'package:vania/database.dart';

class PersonalAccessToken extends Model {
  @override
  String get tableName => 'personal_access_tokens';

  @override
  List<String> get fillable => [
        'name',
        'tokenable_id',
        'token',
        'expires_at',
        'last_used_at',
        'revoked_at',
      ];
}
