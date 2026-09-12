# Vania CLI

**The command line for Vania: create a project, run it while you code, generate the boilerplate, migrate the database, and ship a binary.**

`vania_cli` is the tool you'll live in day to day. It scaffolds a new app from the official starter, runs a dev server that reloads as you edit, generates controllers/models/migrations/and more so you don't hand-write boilerplate, and compiles your app to a single native executable for deployment.

## Install

```bash
dart pub global activate vania_cli
```

That adds the `vania` command globally. If your shell can't find it, add Dart's global bin (usually `~/.pub-cache/bin`) to your `PATH`.

## Start a project

```bash
vania create my_app
cd my_app
vania serve
```

`create` clones the starter template, renames it, generates an `APP_KEY`, and installs dependencies. `serve` boots the app on `http://localhost:8000` and hot-reloads on file changes.

## Commands

**Project**

| Command | What it does |
| --- | --- |
| `vania create <name>` | Scaffold a new project |
| `vania serve` | Dev server with hot reload (`--host`, `--port`, `--no-reload`) |
| `vania down` | Stop the running dev server |
| `vania build` | Compile to a native executable |
| `vania update` | Update the CLI |
| `vania key:generate` | Generate and write a new `APP_KEY` |
| `vania route:list` | Print every registered route |

**Generators**

| Command | What it makes |
| --- | --- |
| `vania make:controller <name>` | A resource controller |
| `vania make:model <name>` | A model |
| `vania make:middleware <name>` | A middleware |
| `vania make:migration <name>` | A migration |
| `vania make:seeder <name>` | A seeder |
| `vania make:provider <name>` | A service provider |
| `vania make:mail <name>` | A mailable |
| `vania make:auth` | The personal access tokens migration |

**Database**

| Command | What it does |
| --- | --- |
| `vania migrate` | Run pending migrations |
| `vania migrate:fresh` | Drop everything and re-run migrations |
| `vania migrate:seed` | Run seeders |

## Ship it

```bash
vania build
```

You get a self-contained binary at `bin/server` that runs without the Dart SDK on the target machine. Deploy it alongside your `.env`, `public/`, and `storage/` folders.

## Links

- Documentation: [vdart.dev/docs](https://vdart.dev/docs/intro)
- Source & issues: [github.com/vania-dart/framework](https://github.com/vania-dart/framework)

## License

MIT
