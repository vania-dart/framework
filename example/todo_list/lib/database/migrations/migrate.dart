import 'dart:io';
import 'package:todo_list/database/task.dart';
import 'package:vania/vania.dart';
import '../../config/database.dart';
import 'create_user_table.dart';

void main() async {
  Env().load();
  await Migrate().registry();
  await MigrationConnection().closeConnection();
  exit(0);
}

class Migrate {
  registry() async {
    await MigrationConnection().setup(databaseConfig);
    await CreateUserTable().up();
    await Task().up();
  }
}
