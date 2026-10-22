# core_showcase

Exercises the HTTP core end to end against the local `packages/core`.

```bash
dart run bin/server.dart          # http://127.0.0.1:8790/console runs the browser checks
dart run tool/check.dart          # request-level checks against the running server
```

`tool/check.dart --isolates` covers `APP_ISOLATES` and graceful shutdown: it
starts and stops its own server.
