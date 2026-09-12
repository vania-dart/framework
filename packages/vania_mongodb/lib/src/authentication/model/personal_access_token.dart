import 'package:vania/database.dart' show Model;

class PersonalAccessToken extends Model {
  @override
  List<String> get guarded => ['_id'];
}
