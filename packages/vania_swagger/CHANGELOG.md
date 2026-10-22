## 1.1.0

- The generated spec is now **OpenAPI 3.2.0** (it was 3.1.0). If you feed the
  spec to other tools, make sure they understand 3.2; Swagger UI does from
  5.32 on.
- Support for the new HTTP `QUERY` method (RFC 10008). Use
  `swaggerQuery(...)`, or `registerRoute(method: 'QUERY')`, and the operation
  lands in the path's `query` field. There's also an `@ApiQueryMethod`
  annotation next to `@ApiGet`, `@ApiPost` and the rest. `@ApiQuery` hasn't
  changed: it still describes a query-string parameter.
- Methods OpenAPI has no field for, like `PURGE`, are written under the
  path's `additionalOperations`. Before, they ended up as top-level keys on
  the path, which isn't valid in any OpenAPI version.
- Swagger UI bumped from 5.11.0 to 5.33.3. It renders 3.2 specs and can send
  `QUERY` requests from "Try it out".

## 1.0.0

First stable release.

- Requires `vania` 2.0.0.
- OpenAPI 3.1.0 output plus Swagger UI, served from the app's own `Router` at
  `GET /docs`, `/docs/swagger.json`, and `/docs/swagger.yaml`. No separate
  `HttpServer` on a second port, and the old `SwaggerUI` type is gone.
- `SwaggerModule.setup(controllers:, models:)` collects routes and DTO schemas,
  with `registerRoute` / `registerModel` as the explicit, AOT-safe path.
- HTTP-verb annotations: `@ApiGet`, `@ApiPost`, `@ApiPut`, `@ApiPatch`,
  `@ApiDelete`.
- `ApiProperty.name` and `ApiSchema.name` are optional — the field or class
  name is used when omitted.
- The UI is **disabled when `APP_ENV` is `production`** by default, so a
  deployment does not publish its API surface by accident.
- Fixed a crash when `basePath` was passed with a trailing slash.
- **Same-port UI.** `SwaggerServiceProvider` registers `GET /docs`,
  `GET /docs/swagger.json`, and `GET /docs/swagger.yaml` on the app's
  `Router` — no more separate `HttpServer.bind(..., 8080)`. The
  previous `SwaggerUI` type has been removed.
- **NestJS-style `SwaggerModule.setup(controllers:, models:)`** —
  walks controller instances and annotated DTO classes via `dart:mirrors`
  and populates `SwaggerMetadata()`.
- **New HTTP-verb annotations**: `@ApiGet`, `@ApiPost`, `@ApiPut`,
  `@ApiPatch`, `@ApiDelete` (all subclasses of `@ApiRoute`).
- **AOT-safe fallback** — `SwaggerModule.registerRoute` /
  `SwaggerModule.registerModel` when `dart:mirrors` isn't available.
- **OpenAPI 3.1.0** (bumped from 3.0.3).
- **YAML output** at `/docs/swagger.yaml` via a hand-rolled emitter — zero
  new deps.
- Fix `basePath.substring(0, -1)` crash when a trailing slash was passed.
- `ApiProperty.name` and `ApiSchema.name` are now optional — when omitted,
  the field / class name is used.
- Removed dead CDN "local-serve" placeholder JS from the old `SwaggerUI`.
