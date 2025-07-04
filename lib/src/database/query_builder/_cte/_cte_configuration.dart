import '_cte_feature.dart';
import '_database_type.dart';

class CteConfiguration {
  final String quoteChar;

  final DatabaseType databaseType;

  final bool enableCaching;

  final int maxCteDepth;

  final bool allowMaterialized;

  final bool allowNotMaterialized;

  final bool allowRecursive;

  const CteConfiguration({
    this.quoteChar = '"',
    this.databaseType = DatabaseType.postgresql,
    this.enableCaching = true,
    this.maxCteDepth = 100,
    this.allowMaterialized = true,
    this.allowNotMaterialized = true,
    this.allowRecursive = true,
  });

  factory CteConfiguration.forDatabase(DatabaseType type) {
    switch (type) {
      case DatabaseType.postgresql:
        return const CteConfiguration(
          quoteChar: '"',
          databaseType: DatabaseType.postgresql,
          allowMaterialized: true,
          allowNotMaterialized: true,
          allowRecursive: true,
        );

      case DatabaseType.mysql:
        return const CteConfiguration(
          quoteChar: '`',
          databaseType: DatabaseType.mysql,
          allowMaterialized: false,
          allowNotMaterialized: false,
          allowRecursive: true,
        );

      case DatabaseType.sqlite:
        return const CteConfiguration(
          quoteChar: '"',
          databaseType: DatabaseType.sqlite,
          allowMaterialized: false,
          allowNotMaterialized: false,
          allowRecursive: true,
        );
    }
  }

  bool supportsFeature(CteFeature feature) {
    switch (feature) {
      case CteFeature.materialized:
        return allowMaterialized;
      case CteFeature.notMaterialized:
        return allowNotMaterialized;
      case CteFeature.recursive:
        return allowRecursive;
    }
  }
}
