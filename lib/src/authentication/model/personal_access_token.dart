import 'package:vania/src/database/orm/model.dart';

class PersonalAccessToken extends Model {
  @override
  List<String> guarded = ['id'];
}
