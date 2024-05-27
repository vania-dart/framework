import 'package:eloquent/eloquent.dart';

abstract class DatabaseDriver {
  const DatabaseDriver();
  String get driver;
  Future<void> init();
  Connection get connection;
  Future<void> close();
}
