import 'package:meta/meta.dart';

abstract class Seeder {
  @mustBeOverridden
  Future<void> run();
}
