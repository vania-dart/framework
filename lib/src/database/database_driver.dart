import 'package:eloquent/eloquent.dart';
import 'package:vania/vania.dart';

abstract class DatabaseDriver {
  const DatabaseDriver();
  String get driver;
  Future<void> init([DatabaseConfig? config]);
  Connection get connection;
  Future<void> close();
}
