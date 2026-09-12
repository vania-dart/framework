---
sidebar_position: 1
---

# Installation & Setup

This page takes you from an empty machine to a running Vania server. It should take a couple of minutes.

## Prerequisites

- **Dart SDK** `>=3.9.0 <4.0.0`
- A terminal
- Git (the project generator clones a starter template over Git)
- Optional: a database server — MySQL, PostgreSQL, or MongoDB — if you plan to use the ORM

Check your Dart version:

```bash
dart --version
# Dart SDK version: 3.9.x (or newer)
```

## Install the CLI

The `vania_cli` package gives you the `vania` command, which scaffolds projects, generates code, runs the dev server, and drives migrations.

```bash
dart pub global activate vania_cli
```

If `vania` is not found afterwards, add Dart's global package bin to your `PATH` (usually `~/.pub-cache/bin`).

## Create a project

```bash
vania create my_app
```

Under the hood this clones the official starter template, removes its Git history, renames the package to `my_app`, generates a fresh `APP_KEY` into `.env`, and runs `dart pub get` for you. When it finishes it prints the next steps:

```bash
cd my_app
vania key:generate   # regenerate the app key if you want a new one
vania serve
```

`vania create` already writes a valid `APP_KEY`, so `key:generate` is optional on a brand-new project — it is there for when you clone an existing repo that ships without one.

## Start the dev server

```bash
vania serve
```

The server listens on `http://localhost:8000` by default (set by `APP_PORT` in `.env`). `serve` restarts the app when you change a file, so you can leave it running while you work.

You can always run the entry point directly instead:

```bash
dart run bin/server.dart
```

## Add a database driver (optional)

The core framework has no database driver built in — you add the one you need. This keeps apps that don't use a database dependency-free.

```bash
dart pub add vania_mysql        # or: vania_postgresql / vania_mongodb
```

Then register the driver in `bin/server.dart`, **before** `Application().initialize`, and `await` the initialization:

```dart
import 'package:vania/vania.dart';
import 'package:vania_mysql/vania_mysql.dart';
import 'package:my_app/config/app.dart';

void main() async {
  registerMySqlDriver();

  await Application().initialize(config: config);
}
```

For the other drivers, call `registerPostgreSqlDriver()` or `registerMongoDbDriver()`. That one call is the only place your app names a specific driver — everything else imports `package:vania/database.dart`. See the driver pages for connection details: [MySQL](../packages/mysql.md), [PostgreSQL](../packages/postgresql.md), [MongoDB](../packages/mongodb.md).

## The `.env` file

Your project root has a `.env` file. At minimum it needs a name, a port, and a key:

```env
APP_NAME=my_app
APP_ENV=local
APP_KEY=a-generated-32-character-minimum-secret
APP_HOST=0.0.0.0
APP_PORT=8000
APP_DEBUG=true
```

`APP_KEY` must be **at least 32 characters** — the framework refuses to start otherwise, because the key signs sessions and other cryptographic tokens. `vania key:generate` writes a suitable one for you. See [Configuration](configuration.md) for every key the framework reads.

## Verify it works

With the server running, hit any route your app defines. A fresh project ships with a sample route under `/api`:

```bash
curl http://localhost:8000/api/home
```

You should get a JSON response back. If the port is taken, change `APP_PORT` in `.env` and restart.

## Build for production

Compile the app to a single native executable that runs without the Dart SDK installed:

```bash
vania build
```

See [Deployment › Docker](../deployment/docker.md) for shipping that binary in a container.

## What's next

- [Configuration](configuration.md) — the config map, environment variables, CORS, and HTTPS.
- [Directory Structure](directory-structure.md) — what each folder is for.
- [Routing](../core/routing.md) — define your first routes.
