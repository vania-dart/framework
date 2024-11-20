import 'package:vaniaFramework/src/localization_handler/localization.dart';

extension LocalizationExtension on String {
  String trans([Map<String, dynamic>? args]) {
    return Localization().trans(this, args);
  }
}
