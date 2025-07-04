import '_cte_exception.dart';

class InvalidCteConfigurationException extends CteException {
  InvalidCteConfigurationException(super.message, [super.cteName]);
}
