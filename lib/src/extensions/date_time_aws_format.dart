extension DateTimeAwsFormat on DateTime {
  String toAwsFormat() {
    String zeroPad(int number) => number.toString().padLeft(2, '0');

    return '${zeroPad(year)}${zeroPad(month)}${zeroPad(day)}T'
        '${zeroPad(hour)}${zeroPad(minute)}${zeroPad(second)}Z';
  }
}
