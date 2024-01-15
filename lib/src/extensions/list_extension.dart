extension ListExtension on List<String> {
  String joinWithAnd([String separator = ', ', String lastJoinText = 'and']) {
    List<dynamic> items = this;
    if (items.length <= 1) {
      return items.join();
    } else {
      String lastItem = items.removeLast();
      String joinedItems = items.join(separator);
      return '$joinedItems, $lastJoinText $lastItem';
    }
  }
}