# Vania WebSocket

**Real-time features for Vania: rooms, channels, presence, and broadcasting — over a single connection on your existing port.**

`vania_websocket` adds real-time messaging to a Vania app. You register event handlers, group connections into rooms and channels, track who's online with presence, and broadcast to one client, a room, or everyone. It runs on your app's normal HTTP port, so there's no second server to deploy or expose.

## Install

```yaml
dependencies:
  vania_websocket: ^1.0.0
```

Register the provider:

```dart
final providers = <ServiceProvider>[
  WebSocketServiceProvider(),
];
```

## Handle events

Every frame is `{ "event": "...", "payload": { ... } }`. A handler receives the payload, the raw socket, and a context map whose `session_id` identifies the connection:

```dart
import 'package:vania_websocket/vania_websocket.dart';

final ws = VaniaWebSocketService();

ws.on('chat:message', (payload, socket, context) async {
  final room = (payload as Map)['room'] as String;
  ws.emitToRoom(room, 'chat:message', payload);
});
```

## Broadcast

```dart
ws.emitToRoom('game_lobby', 'update', {'players': 4}); // to a room
ws.sendTo(sessionId, 'notification', {'text': 'Hi'});   // to one connection
ws.broadcast('announcement', {'text': 'Restarting'});   // to everyone
```

## What's included

- **Rooms** — lightweight groupings for broadcasting; join, leave, and list members.
- **Channels** — a higher-level grouping for organizing subscriptions.
- **Presence** — `WebSocketPresence()` tracks who's online, with change events and per-user messaging.
- **Connection introspection** — `connectionCount`, `connectionIds`, `hasConnection`, `getConnectionInfo`, `close`, `closeAll`.
- **Middleware** — authenticate or rate-limit socket connections before they're accepted.

## A note on design

Keep your real-time logic in a plain, transport-free object and let the handlers just unpack the payload and call it. That keeps everything unit-testable without a live socket — see the WebSocket chat walkthrough in the docs for the full pattern.

## Links

- Documentation: [vdart.dev/docs](https://vdart.dev/docs/intro)
- Source & issues: [github.com/vania-dart/framework](https://github.com/vania-dart/framework)

## License

MIT
