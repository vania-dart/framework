# WebSocket Chat Example

A real-time chat built with the [Vania](../../packages/core) framework and
[`vania_websocket`](../../packages/vania_websocket). It shows rooms, messages,
a typing indicator, and join/leave presence — all over a single WebSocket
connection on the app's HTTP port.

## Design

All chat logic lives in a transport-free [`ChatHub`](lib/chat/chat_hub.dart):
it tracks rooms, membership, and usernames, and delivers events through an
injected `ChatSender`. The [`ChatServiceProvider`](lib/chat/chat_service_provider.dart)
wires that hub onto `VaniaWebSocketService` — connection lifecycle drives
connect/disconnect, and each client event maps to one hub call. Because the
hub has no socket dependency, it is unit-tested with a fake sender.

```
lib/
  chat/chat_hub.dart              # rooms, messages, typing, presence (pure logic)
  chat/chat_service_provider.dart # binds the hub to the WebSocket service
  config/app.dart                 # WebSocketServiceProvider + ChatServiceProvider
bin/server.dart
public/index.html                 # minimal browser client
test/chat_hub_test.dart
```

## Protocol

Every frame is `{ "event": "...", "payload": { ... } }`.

**Client → server**

| Event         | Payload             | Effect                              |
|---------------|---------------------|-------------------------------------|
| `set-name`    | `{ name }`          | Set the display name                |
| `create-room` | `{ room }`          | Create a room and join it           |
| `join`        | `{ room }`          | Join an existing room               |
| `leave`       | `{ room }`          | Leave a room                        |
| `message`     | `{ room, text }`    | Send a message to the room          |
| `typing`      | `{ room }`          | Signal "typing" to the other members |

**Server → client**

`rooms`, `name-set`, `room-created`, `joined`, `user-joined`, `user-left`,
`left`, `message`, `typing`.

> Note: the service reserves the built-in event names `join-room`/`leave-room`,
> so this sample uses `join`/`leave`.

## Running

```bash
dart pub get
dart run bin/server.dart
```

Then open [`public/index.html`](public/index.html) in a browser (it connects
to `ws://localhost:8000/chat`). Open it in two tabs, join the same room, and
chat. Adjust the host/port in the HTML if your server differs.

## Tests

```bash
dart test
```
