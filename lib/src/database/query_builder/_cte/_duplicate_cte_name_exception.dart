import '_cte_exception.dart';

class DuplicateCteNameException extends CteException {
  DuplicateCteNameException(String name)
      : super('CTE with name "$name" already exists', name);
}
