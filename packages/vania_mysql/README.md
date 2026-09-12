# Vania MySQL

**The MySQL (and MariaDB) driver for Vania's ORM.**

`vania_mysql` is the piece that lets Vania talk to a real MySQL database. It's deliberately thin: it contributes the connection that speaks the MySQL wire protocol, and nothing else. Everything you actually write — models, the query builder, relations, migrations, seeders — comes from the core framework and works unchanged once this driver is registered.

That separation is the whole point. Your app imports `package:vania/database.dart` and never mentions MySQL. The word "mysql" appears in exactly one place: the `registerMySqlDriver()` call at boot. Move to PostgreSQL later and that one line (plus your connection settings) is all that changes.

## Install

```yaml
dependencies:
  vania: ^2.0.0
  vania_mysql: ^1.0.0
```

## Register the driver

Call it once in `bin/server.dart`, before the app initializes:

```dart
import 'package:vania/vania.dart';
import 'package:vania_mysql/vania_mysql.dart';
import 'package:my_app/config/app.dart';

void main() async {
  registerMySqlDriver();

  await Application().initialize(config: config);
}
```

Registered names: `mysql`, `mariadb`.

## Configure the connection

```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=my_app
DB_USERNAME=root
DB_PASSWORD=secret
```

## Then just use the ORM

```dart
import 'package:vania/database.dart';

final users = await DB.table('users')
    .where('active', '=', true)
    .orderBy('created_at', 'desc')
    .get();

final user = await User().query.where('email', '=', 'a@b.com').first();
```

## Good to know

- New tables default to InnoDB with `utf8mb4`, so full Unicode (emoji included) just works.
- `schema.id()` gives you an unsigned `BIGINT` auto-increment primary key.
- Booleans are stored as `TINYINT(1)` and read back as Dart `bool`.
- Connections are pooled and managed for you — you never open or close them by hand.
- MariaDB speaks the same protocol and works with this driver.

## Links

- Documentation: [vdart.dev/docs](https://vdart.dev/docs/intro)
- Source & issues: [github.com/vania-dart/framework](https://github.com/vania-dart/framework)

## License

MIT
