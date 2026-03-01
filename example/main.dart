import 'package:vania/vania.dart';
import 'package:vania/src/exception/app_exception_handler.dart';

void main() async {
  Application().initialize(
    config: {
      'providers': [AppExceptionServiceProvider()],
    },
  );
}
