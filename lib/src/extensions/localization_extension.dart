import 'package:vania/src/localization_handler/localization.dart';

extension LocalizationExtension on String {
  String trans({
    Map<String, dynamic>? args,
    String? locale,
  }) {
    return Localization().trans(this, args, locale);
  }
}
