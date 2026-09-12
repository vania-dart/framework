---
sidebar_position: 6
---

# Walkthrough: WebSocket Chat

**Sample:** `examples/websocket_chat` · **Needs:** nothing extra

A real-time chat with rooms, messages, a typing indicator, and join/leave presence — all over a single WebSocket connection running on the app's normal HTTP port. It is the clearest example of the split this repo keeps returning to: all the chat *logic* lives in a transport-free object, and the WebSocket wiring is a thin layer that calls into it.

See the [WebSocket](../../packages/websocket.md) package page for the service API.

## Run it

```bash
cd examples/websocket_chat
dart pub get
dart run bin/server.dart
```

Open `public/index.html` in two browser tabs (it connects to `ws://localhost:8000/chat`), join the same room in both, and chat.

## The protocol

Every frame in both directions is `{ "event": "...", "payload": { ... } }`.

**Client → server:** `set-name`, `create-room`, `join`, `leave`, `message`, `typing`.
**Server → client:** `rooms`, `name-set`, `room-created`, `joined`, `user-joined`, `user-left`, `left`, `message`, `typing`.

> The service reserves the built-in names `join-room`/`leave-room`, so this sample uses `join`/`leave` for its own events.

## The hub: all the logic, none of the sockets

`ChatHub` tracks rooms, membership, and usernames. It never touches a socket. Instead it delivers everything through an injected function:

```dart
// lib/chat/chat_hub.dart
typedef ChatSender = void Function(String sessionId, String event, Object? payload);

class ChatHub {
  ChatHub(this._send);
  final ChatSender _send;

  final Set<String> _sessions = {};
  final Map<String, String> _names = {};          // sessionId -> username
  final Map<String, Set<String>> _rooms = {};      // room -> sessionIds

  void join(String sessionId, String room) {
    _rooms.putIfAbsent(room, () => <String>{}).add(sessionId);
    _send(sessionId, 'joined', {'room': room, 'members': membersOf(room)});
    _toOthers(room, sessionId, 'user-joined', {'room': room, 'user': nameOf(sessionId)});
  }

  void message(String sessionId, String room, String text) {
    if (!_isMember(sessionId, room)) return;          // ignore messages to rooms you're not in
    _toRoom(room, 'message', {'room': room, 'from': nameOf(sessionId), 'text': text});
  }
  // ... setName, createRoom, leave, typing, connect, disconnect
}
```

Two helpers do all the fan-out:

```dart
void _toRoom(String room, String event, Object? payload) {
  for (final session in _rooms[room] ?? const <String>{}) {
    _send(session, event, payload);
  }
}

void _toOthers(String room, String except, String event, Object? payload) {
  for (final session in _rooms[room] ?? const <String>{}) {
    if (session != except) _send(session, event, payload);
  }
}
```

`_toRoom` includes you (used for messages); `_toOthers` excludes you (used for "someone is typing" and join/leave notices). Because the hub only calls `_send`, it has no dependency on WebSockets at all — which is exactly why it can be unit-tested with a fake sender.

## Wiring the hub onto the WebSocket service

The provider connects the hub's `_send` to the real socket service and maps each incoming event to one hub call:

```dart
// lib/chat/chat_service_provider.dart
Future<void> boot() async {
  final ws = VaniaWebSocketService();
  final hub = ChatHub((sessionId, event, payload) => ws.sendTo(sessionId, event, payload));

  ws.onConnectionChanged.listen((event) {
    switch (event.type) {
      case WebSocketConnectionEventType.connected:
        hub.connect(event.sessionId);
      case WebSocketConnectionEventType.disconnected:
        hub.disconnect(event.sessionId);
    }
  });

  String sid(Map<String, dynamic> ctx) => ctx['session_id'] as String;
  String room(dynamic p) => (p as Map)['room'] as String;

  ws.on('set-name',    (p, s, c) async => hub.setName(sid(c), (p as Map)['name'] as String));
  ws.on('create-room', (p, s, c) async => hub.createRoom(sid(c), room(p)));
  ws.on('join',        (p, s, c) async => hub.join(sid(c), room(p)));
  ws.on('leave',       (p, s, c) async => hub.leave(sid(c), room(p)));
  ws.on('message',     (p, s, c) async => hub.message(sid(c), room(p), (p as Map)['text'] as String));
  ws.on('typing',      (p, s, c) async => hub.typing(sid(c), room(p)));
}
```

Read this file as a table of contents: connection lifecycle drives `connect`/`disconnect`, and each client event is one line that unpacks the payload and calls the matching hub method. There is no logic here — the logic is all in the hub.

## Presence, for free

Notice `disconnect` in the hub removes the session from every room it was in and notifies the others with `user-left`. So presence — knowing who is currently in a room — is not a separate feature; it falls out of tracking membership and reacting to the socket closing. When a browser tab closes, the service fires `disconnected`, the hub cleans up, and everyone else sees the person leave.

## The config

```dart
// lib/config/app.dart
'providers': <ServiceProvider>[
  WebSocketServiceProvider(),   // adds the /chat WebSocket endpoint
  ChatServiceProvider(),        // wires the hub onto it
],
```

The WebSocket runs on the same HTTP port as the rest of the app — there is no second server to deploy or expose.

## Testing without a socket

The hub is constructed with a fake sender that records `(sessionId, event, payload)` tuples, then driven through join/message/leave, asserting on what each participant would have received:

```bash
dart test
```

No server, no browser, no real socket — because the transport is injected.

## What to take away

- Keep real-time **logic** in a transport-free object; make the socket wiring a thin dispatcher on top.
- Inject the "send" function so the logic can be tested with a fake.
- **Presence** is a side effect of tracking membership plus reacting to disconnects — not a separate system.
- A Vania WebSocket lives on the app's existing HTTP port; no separate server.
