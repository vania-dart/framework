import '_cte_exception.dart';
import '_cte_feature.dart';
import '_database_type.dart';

class UnsupportedCteFeatureException extends CteException {
  final CteFeature feature;

  final DatabaseType databaseType;

  UnsupportedCteFeatureException(
    this.feature,
    this.databaseType, [
    String? cteName,
  ]) : super(
         'Feature ${feature.name} is not supported in ${databaseType.name}',
         cteName,
       );
}
