## 1.0.0

First stable release.

- Requires `vania` 2.0.0.
- Redis cache driver, pub/sub, and Lua scripting behind one `Redis()`
  singleton.
- `RedisScript.fromFile` and `RedisScriptRepository` load Lua scripts from a
  directory at boot, cache their SHAs, and fall back from `EVALSHA` to `EVAL`
  on `NOSCRIPT`.
- `RedisPubSub.attach()` / `own()` with an explicit `close()` for the dedicated
  Pub/Sub connection.
- `RedisServiceProvider` takes an optional `RedisConfig` and, with `warmUp`
  set, opens the connection and loads scripts during `boot()`.

## 0.2.0

- Add `RedisScript.fromFile` and `RedisScriptRepository` — load Lua scripts
  from a directory at boot, cache SHAs on the instance, and fall back from
  `EVALSHA` to `EVAL` transparently on `NOSCRIPT`.
- Add `RedisPubSub.close()` — release the dedicated Pub/Sub connection
  cleanly. `RedisPubSub.attach()` / `RedisPubSub.own()` replace the
  deprecated `RedisPubSub.create`.
- Add `Redis().pubsub<T>()` and `Redis().scripts` on the singleton.
- `RedisServiceProvider` now takes an optional `RedisConfig?` and, when
  `warmUp` is set, opens the connection eagerly + loads Lua scripts from
  the configured directory during `boot()`.
- New env keys: `REDIS_SCRIPTS_PATH`, `REDIS_WARM_UP`.

## 0.1.0

- Initial version.
