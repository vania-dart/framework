extension NumberExtension on num {
  num toFixed(int decimal) {
    return num.parse(toStringAsFixed(decimal));
  }
}
