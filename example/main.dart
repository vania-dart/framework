import 'package:vania/vania.dart';
import 'app_exception_handler.dart';

void main() async {
  Application().initialize(
    config: {
      'providers': [AppExceptionServiceProvider()],
    },
  );
}
