



import 'package:eloquent/eloquent.dart';

abstract class DatabaseDriver{
  const DatabaseDriver();
  Future<void> init();
  Connection get connection;
}