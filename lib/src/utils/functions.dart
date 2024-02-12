import 'dart:math';

String sanitizeRoutePath(String path) {
  path = path.replaceAll(RegExp(r'/+'), '/');
  return path.replaceAll(RegExp('^\\/+|\\/+\$'), '');
}

String genrateRandomString([int length = 32]) {
  const chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  Random rnd = Random();
  return String.fromCharCodes(Iterable.generate(
      length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
}
