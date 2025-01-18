import 'dart:math';

/// Sanitizes a route path by replacing multiple slashes with a single slash and
/// removing leading and trailing slashes.
String sanitizeRoutePath(String path) {
  path = path.replaceAll(RegExp(r'/+'), '/');
  return path.replaceAll(RegExp('^\\/+|\\/+\$'), '');
}

/// Generates a random string of a given [length] with the given character set.
///
/// The default length is 32. The default character set is all letters of the
/// alphabet, both lowercase and uppercase. If [numbers] or [special] is true,
/// the character set is extended to include numbers or special characters,
/// respectively. The generated string is a random permutation of the characters
/// in the character set.
String randomString({
  int length = 32,
  bool numbers = false,
  bool special = false,
}) {
  List<String> strList =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');

  if (numbers) {
    strList.addAll('1234567890'.split(''));
  }

  if (special) {
    strList.addAll('!@#%^&*()_'.split(''));
  }

  strList.shuffle();
  String chars = strList.join('');
  Random rnd = Random();
  return String.fromCharCodes(Iterable.generate(
      length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
}

/// Generate a random number as a string of a given length
///
/// If T is int, it will be parsed as an integer and returned as a int
/// otherwise, it will be returned as a string
///
/// The generated numbers are all positive
///
/// The default length is 6
///
/// [length] is the length of the generated number
///
/// Returns a random number as a string of [length] length
///
/// Example:
///
///     var rand = randomInt(); // '123456'
///     var rand = randomInt(3); // '246'
///     var rand = randomInt<int>(3); // 246
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
