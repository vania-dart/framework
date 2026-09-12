import 'package:vania/vania.dart';
import 'package:grpc_greeter/config/app.dart';

void main(List<String> arguments) async {
  await Application().initialize(config: config);
}
