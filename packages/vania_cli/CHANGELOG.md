## 3.0.0

- Added incremental hot reload through the Dart VM Service. Source saves now
  call `reloadSources` once on the primary isolate with `force: false`, so the
  VM recompiles only modified libraries and required dependants while keeping
  the server process alive.
- Added debounced `lib/` watching and interactive serve controls: `r` reloads,
  `R` restarts, `l` lists routes, `c` clears the terminal, and `q` quits.
- Added `--host`, `--port`, `--no-reload`, and `--no-watch` serve options.
- Added `route:list` with method, path, name, and JSON filters.
- Added `key:generate` with safe existing-key handling and `--show`/`--force`.
- Added `Console`, `Stubs`, `StubCommand`, and streaming process utilities.
- Commands now return meaningful exit codes, expose help/usage, and can be
  rooted in an injected working directory for deterministic tests.
- Preserved all 2.x commands, including alter-table migrations, migration
  lifecycle commands, database seeders, and port termination.
- Added unit and real-VM integration coverage for command dispatch, stub
  generation, APP_KEY generation, route parsing, and incremental hot reload.

## 2.0.0

- Integrated with `Vania` v1

## 1.3.0

- Fix migration deop table
- Add create new alter table migration

## 1.2.1

- Fix migration filename extensions
- Fix add migration, if `dropTables` does not exist bug

## 1.2.0

- Add DB Seed
- Add Migrate fresh
- Fix migration name
- Refactor `print` to `stdout.writeln`

## 1.1.0

- Add Terminate open port
- Fix serve command issue

## 1.0.0

- Add Hot reload
- Refactor migration

## 0.0.8

- Add Auth command

## 0.0.7+1

- Fix name issues on all commands

## 0.0.7

- Refactor create new project command
- Fix RegExp when create new file

## 0.0.6

- Add make mail command
- Fix import path
  
## 0.0.5

- Add serve down by [babakcode](https://github.com/babakcode)

## 0.0.4+4

- Fix On creting new project

## 0.0.4+3

- Changing Vania new to the Vania create to create the project
- Add hint-text when project created

## 0.0.4+2

- Fix bug: exit process when upload file
- Add toLowerCase for vm flag

## 0.0.4+1

- Fix bug: vm serve

## 0.0.4

- Update minimum Dart SDK support to version 3.0.0
- Add support for enabling VM service
- Refactor `make:service_provider` command to `make:provider`
- Fix bug related to controller naming

## 0.0.3+2

- Fix create model

## 0.0.3+1

- Fix create new project

## 0.0.3

- Add create service provider
- Add vania version from api
- Add run command from vania project

## 0.0.2+1

- Fix new controller path
- Add dart pub add vania
  
- ## 0.0.2

- Fix path

## 0.0.1+1-alpha

- Alpha version.
