extension DateTimeAwsFormat on DateTime {
  String toAwsFormat() {
    String zeroPad(int number) => number.toString().padLeft(2, '0');

    return '${zeroPad(year)}${zeroPad(month)}${zeroPad(day)}T'
        '${zeroPad(hour)}${zeroPad(minute)}${zeroPad(second)}Z';
  }
}

extension DateTimeFormatting on DateTime {
  String format() {
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')} '
        '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}:'
        '${second.toString().padLeft(2, '0')}';
  }
}
