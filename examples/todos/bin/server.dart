import 'package:vania/vania.dart';
import 'package:todos/config/app.dart';

void main(List<String> arguments) async {
  await Application().initialize(config: config);
}
