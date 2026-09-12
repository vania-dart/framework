import 'package:vania/database.dart' show Model;
import 'package:vania_elasticsearch/vania_elasticsearch.dart';

/// A `Model` made searchable. `Searchable` uses the table name as the
/// index (`articles`) and `toJson()` as the indexed body by default.
class Article extends Model with Searchable {
  Article({int? id, String? title, String? body}) {
    tableName = 'articles';
    if (id != null) attributes['id'] = id;
    if (title != null) attributes['title'] = title;
    if (body != null) attributes['body'] = body;
  }
}
