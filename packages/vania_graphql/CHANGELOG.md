## 1.0.0

First stable release.

- Requires `vania` 2.0.0.
- Schema registration, execution, an HTTP endpoint, and the GraphiQL console.
- Subscriptions over both SSE and the `graphql-transport-ws` WebSocket
  protocol, served on the app's single HTTP port through core's
  `WebSocketUpgradeDispatcher`. The dispatcher override composes with
  `vania_websocket`, so both can run together.
- `GraphQLConfig` covers `subscriptionsOverWebSocket`, `subscriptionsEndpoint`,
  and `keepAliveInterval`.
- GraphiQL and schema introspection are **disabled when `APP_ENV` is
  `production`**, since they publish your entire schema. Set
  `GRAPHQL_GRAPHIQL_ENABLED` / `GRAPHQL_INTROSPECTION_ENABLED` to override, and
  put the endpoint behind auth if you do.
- Routes are registered in `boot()` rather than `register()`, so downstream
  providers can adjust the config first.
- Subscriptions now also flow over the `graphql-transport-ws` WebSocket
  protocol on the app's single HTTP port. `GraphQLServiceProvider` installs
  a `GraphQLWsDispatcher` that composes with any pre-existing
  `WebSocketUpgradeDispatcher` override (e.g. `vania_websocket`), so both
  can coexist.
- `GraphQLConfig` gains `subscriptionsOverWebSocket`,
  `subscriptionsEndpoint`, and `keepAliveInterval`.
- Route registration moved from `register()` to `boot()` so downstream
  providers can influence config first.
- GraphiQL page bumped to GraphiQL 3, wired to both `/graphql` and
  `/graphql/ws`. `renderMinimal()` fallback kept for offline dev.