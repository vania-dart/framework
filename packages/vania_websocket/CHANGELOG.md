## 1.0.0

First release wired into the HTTP pipeline. The service existed before but was
never reachable from a running app.

- Requires `vania` 2.0.0.
- `WebSocketServiceProvider.boot()` overrides core's
  `WebSocketUpgradeDispatcher`, so every upgrade the app's HTTP server receives
  is handled by `VaniaWebSocketService`. Channels, rooms, presence, and rate
  limiting all run on **the app's single port** — no second `HttpServer`, no
  second port.
- `WebSocketConfig(enabled: false)` resets the dispatcher back to core's
  built-in handler.
- The provider composes with other dispatcher overrides (for example
  `vania_graphql` subscriptions), so both can serve WebSockets at once.
- An integration test boots the provider on an ephemeral port and proves both
  that WebSocket upgrades reach the service and that plain HTTP on the same
  port still works.
