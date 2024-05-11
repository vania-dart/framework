import 'package:vania/vania.dart';

DatabaseConfig databaseConfig = DatabaseConfig(
  driver: MysqlDriver(),
  host: env('DB_HOST'),
  port: env('DB_PORT'),
  database: env('DB_DATABASE'),
  username: env('DB_USERNAME'),
  password: env('DB_PASSWORD'),
);
