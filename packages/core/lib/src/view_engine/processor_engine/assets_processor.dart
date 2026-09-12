import 'package:vania/src/utils/helper.dart';

import 'abs_processor.dart';

class AssetsProcessor implements AbsProcessor {
  @override
  String parse(String content, [Map<String, dynamic>? context]) {
    final assetsPattern = RegExp(
      r"(\/?)\{@\s*assets\(\s*'([^']*)'\s*\)\s*@\}",
      dotAll: true,
    );

    return content.replaceAllMapped(assetsPattern, (match) {
      final assets = match.group(2);
      return url(assets ?? '');
    });
  }
}
