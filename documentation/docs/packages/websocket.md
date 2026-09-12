---
sidebar_position: 10
---

# WebSocket (vania_websocket)

The `vania_websocket` package extends the core WebSocket support with channels, rooms, presence tracking, rate limiting, and authentication.

## Installation

```yaml
dependencies:
  vania_websocket: ^1.0.0
```

## Setup

Register the service provider:

```dart
'providers': [
  RouteServiceProvider(),
  WebSocketServiceProvider(),
],
```

Enable WebSocket in `.env`:

```env
APP_WEBSOCKET=true
```

The WebSocket service upgrades HTTP connections at the path defined in the WebSocket config (default: the main server port). Both HTTP and WebSocket traffic share the same port.

## Configuration

```dart
WebSocketConfig(
  enabled: true,
  pingInterval: Duration(seconds: 30),
  timeout: Duration(seconds: 60),
  maxConnections: 10000,
  maxRoomsPerClient: 50,
  enablePresence: true,
  enableRateLimit: true,
  rateLimitMax: 100,
  rateLimitWindow: Duration(minutes: 1),
);
```

## Event Handling

### Register Event Handlers

Every handler receives three arguments: the message `payload`, the raw `socket`, and a `context` map. The current connection's id is `context['session_id']`:

```dart
import 'package:vania_websocket/vania_websocket.dart';

final ws = VaniaWebSocketService();

ws.on('chat:message', (payload, socket, context) async {
  final room = (payload as Map)['room'] as String;
  ws.emitToRoom(room, 'chat:message', payload);
});

ws.on('typing', (payload, socket, context) async {
  final sessionId = context['session_id'] as String;
  final room = (payload as Map)['room'] as String;
  // Notify the room that this connection is typing
  ws.emitToRoom(room, 'typing', {'from': sessionId});
});
```

Keep the handlers thin: unpack the payload, then call a service method. The [WebSocket Chat walkthrough](../tutorials/examples/websocket-chat.md) shows this pattern with all the logic in a transport-free hub.

### Built-in Events

The service handles these events automatically:

| Event | Description |
|-------|-------------|
| `join-room` | Client joins a room |
| `leave-room` | Client leaves a room |
| `join-channel` | Client joins a channel |
| `leave-channel` | Client leaves a channel |
| `ping` | Keep-alive ping |
| `set-data` | Store custom data on the connection |

## Rooms

Rooms are lightweight groupings for broadcasting:

```dart
// Send to all members of a room
VaniaWebSocketService().emitToRoom('game_lobby', 'update', {'players': 4});

// Send to a specific connection
VaniaWebSocketService().sendTo(sessionId, 'notification', {'text': 'Hello!'});

// Broadcast to everyone (optionally excluding sender)
VaniaWebSocketService().broadcast('announcement', {'text': 'Server restarting'});

// Get room members
var members = VaniaWebSocketService().getRoomMembers('game_lobby');
```

## Channels

Channels provide named, managed communication groups:

```dart
var channelManager = WebSocketChannelManager();

// Create or get a channel
var channel = channelManager.getOrCreateChannel('notifications');

// Add a member
channelManager.joinChannel('notifications', sessionId);

// Emit to channel members
channelManager.emitToChannel('notifications', 'alert', {'message': 'New update'});

// Remove a member
channelManager.leaveChannel('notifications', sessionId);
```

## Presence Tracking

Track which users are online:

```dart
var presence = WebSocketPresence();

// Check if a user is online
bool isOnline = presence.isOnline('user_42');

// Get user data
var userData = presence.getUser('user_42');

// Listen for presence changes
presence.onPresenceChanged.listen((event) {
  print('${event.userId} ${event.type}'); // connected / disconnected
});

// Broadcast to all online users
presence.broadcast('system', {'message': 'Maintenance in 5 minutes'});

// Send to a specific user
presence.sendToUser('user_42', 'notification', {'text': 'You have a new message'});
```

## Authentication Middleware

Authenticate WebSocket connections using bearer tokens:

```dart
VaniaWebSocketService().middleware('*', WebSocketAuthMiddleware());
```

The middleware extracts the token from the query string (`?token=...`) or the `Authorization` header, validates it through the auth system, and records presence.

## Rate Limiting

Prevent abuse with per-connection rate limiting:

```dart
VaniaWebSocketService().middleware('*', WebSocketRateLimitMiddleware());
```

The rate limiter uses a sliding window algorithm. Configure limits through `WebSocketConfig`.

## Connection Management

```dart
// Connection count
int count = VaniaWebSocketService().connectionCount;

// All connection IDs
List<String> ids = VaniaWebSocketService().connectionIds;

// Check if connected
bool connected = VaniaWebSocketService().hasConnection(sessionId);

// Get connection info
var info = VaniaWebSocketService().getConnectionInfo(sessionId);

// Close a specific connection
VaniaWebSocketService().close(sessionId);

// Close all connections
VaniaWebSocketService().closeAll();
```

## Client-Side Connection

Connect from a browser or Dart client:

```javascript
// JavaScript
const ws = new WebSocket('ws://localhost:8000?token=your_jwt_token');

ws.onopen = () => {
  // Join a room
  ws.send(JSON.stringify({event: 'join-room', data: {room: 'chat'}}));

  // Send a message
  ws.send(JSON.stringify({event: 'chat:message', data: {text: 'Hello!'}}));
};

ws.onmessage = (event) => {
  const msg = JSON.parse(event.data);
  console.log(msg.event, msg.data);
};
```
