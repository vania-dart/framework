import 'dart:math';

String sanitizeRoutePath(String path) {
  path = path.replaceAll(RegExp(r'/+'), '/');
  return path.replaceAll(RegExp('^\\/+|\\/+\$'), '');
}

String genrateRandomString([int length = 32]) {
  const _chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  Random _rnd = Random();
  return String.fromCharCodes(Iterable.generate(
      length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));
}
