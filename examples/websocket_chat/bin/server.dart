import 'package:vania/vania.dart';
import 'package:websocket_chat/config/app.dart';

void main(List<String> arguments) async {
  await Application().initialize(config: config);
}
