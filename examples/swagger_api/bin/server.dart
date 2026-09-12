import 'package:vania/vania.dart';
import 'package:swagger_api/config/app.dart';

void main(List<String> arguments) async {
  await Application().initialize(config: config);
}
