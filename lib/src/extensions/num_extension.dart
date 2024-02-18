import 'dart:math';

extension NumberExtension on num {
  num toFixed(int decimal) {
    num mod = pow(10.0, decimal);
    return (this * mod).round() / mod;
  }
}
