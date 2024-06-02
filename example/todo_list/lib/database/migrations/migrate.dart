import 'dart:io';
import 'package:vania/vania.dart';
import 'create_user_table.dart';

void main() async {
  Env().load();
  await Migrate().registry();
  await MigrationConnection().closeConnection();
  exit(0);
}

class Migrate {
  registry() async {
    await MigrationConnection().setup();
    await CreateUserTable().up();
  }
}
