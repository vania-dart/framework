import 'package:vania/vania.dart';
import 'package:elasticsearch_search/config/app.dart';

void main(List<String> arguments) async {
  await Application().initialize(config: config);
}
