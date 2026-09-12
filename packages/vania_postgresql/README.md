# Vania PostgreSQL

**The PostgreSQL driver for Vania's ORM.**

`vania_postgresql` connects Vania to PostgreSQL. Like the other drivers it's a thin bridge — it supplies the connection and lets the core framework's ORM, query builder, migrations, and seeders do the rest. If you've used the MySQL driver, this one has the exact same shape by design; only the connection settings, the registration call, and a few Postgres-specific behaviours differ.

Your application code stays database-agnostic: it imports `package:vania/database.dart` and never names PostgreSQL. The one Postgres-specific line is `registerPostgreSqlDriver()` at startup.

## Install

```yaml
dependencies:
  vania: ^2.0.0
  vania_postgresql: ^1.0.0
```

## Register the driver

```dart
import 'package:vania/vania.dart';
import 'package:vania_postgresql/vania_postgresql.dart';
import 'package:my_app/config/app.dart';

void main() async {
  registerPostgreSqlDriver();

  await Application().initialize(config: config);
}
```

Registered names: `pgsql`, `postgres`, `postgresql`.

## Configure the connection

```env
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=my_app
DB_USERNAME=postgres
DB_PASSWORD=secret
```

## Use the ORM

```dart
import 'package:vania/database.dart';

final orders = await DB.table('orders')
    .where('status', '=', 'paid')
    .whereBetween('total_cents', [1000, 50000])
    .get();
```

## Postgres-specific notes

- Uses `$1, $2, …` positional parameters under the hood — the query builder handles that for you, so your Dart is identical to any other driver.
- `schema.id()` maps to `BIGSERIAL PRIMARY KEY`; inserts use `RETURNING id`.
- PostgreSQL has a native `boolean` type, so booleans round-trip cleanly.
- Keep identifiers lower snake_case (the ORM default) and case-folding never surprises you.
- Managed hosts (RDS, Cloud SQL, Supabase) usually require TLS — point `DB_HOST` at the provider and enable SSL.

## Links

- Documentation: [vdart.dev/docs](https://vdart.dev/docs/intro)
- Source & issues: [github.com/vania-dart/framework](https://github.com/vania-dart/framework)

## License

MIT
