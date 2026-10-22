import 'package:vania/vania.dart';
import 'package:core_showcase/config/app.dart';

void main(List<String> args) async {
  await Application().initialize(config: config, args: args);
}
