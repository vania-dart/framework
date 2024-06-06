import 'dart:math';

String sanitizeRoutePath(String path) {
  path = path.replaceAll(RegExp(r'/+'), '/');
  return path.replaceAll(RegExp('^\\/+|\\/+\$'), '');
}

String randomString([int length = 32]) {
  List<String> strList =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz'.split('');
  strList.shuffle();
  String chars = strList.join('');
  Random rnd = Random();
  return String.fromCharCodes(Iterable.generate(
      length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
}

T randomInt<T>([int length = 6]) {
  List<String> strList = '1234567890'.split('');
  strList.shuffle();
  String chars = strList.join('');
  Random rnd = Random();
  String random = String.fromCharCodes(Iterable.generate(
      length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));

  if (T is int) {
    return int.parse(random) as T;
  }
  return random as T;
}
