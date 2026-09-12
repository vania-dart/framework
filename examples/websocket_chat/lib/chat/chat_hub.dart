/// Delivers one event to one connection. The hub calls this instead of
/// touching sockets directly, which keeps the chat logic pure and testable
/// (the WebSocket service supplies the real sender; tests supply a fake).
typedef ChatSender = void Function(
  String sessionId,
  String event,
  Object? payload,
);

/// All the chat logic — rooms, membership, messages, typing, join/leave —
/// with no dependency on the WebSocket transport.
class ChatHub {
  ChatHub(this._send);

  final ChatSender _send;

  final Set<String> _sessions = {};
  final Map<String, String> _names = {}; // sessionId -> username
  final Map<String, Set<String>> _rooms = {}; // room -> sessionIds

  List<String> get rooms => _rooms.keys.toList();

  String nameOf(String sessionId) => _names[sessionId] ?? 'anonymous';

  List<String> membersOf(String room) =>
      (_rooms[room] ?? const <String>{}).map(nameOf).toList();

  void connect(String sessionId) {
    _sessions.add(sessionId);
    _send(sessionId, 'rooms', {'rooms': rooms});
  }

  void disconnect(String sessionId) {
    for (final room in _roomsOf(sessionId)) {
      _leave(sessionId, room, notifySelf: false);
    }
    _sessions.remove(sessionId);
    _names.remove(sessionId);
  }

  void setName(String sessionId, String name) {
    _names[sessionId] = name;
    _send(sessionId, 'name-set', {'name': name});
  }

  void createRoom(String sessionId, String room) {
    final isNew = !_rooms.containsKey(room);
    _rooms.putIfAbsent(room, () => <String>{});
    if (isNew) {
      for (final session in _sessions) {
        _send(session, 'room-created', {'room': room});
      }
    }
    join(sessionId, room);
  }

  void join(String sessionId, String room) {
    _rooms.putIfAbsent(room, () => <String>{}).add(sessionId);
    _send(sessionId, 'joined', {'room': room, 'members': membersOf(room)});
    _toOthers(room, sessionId, 'user-joined', {
      'room': room,
      'user': nameOf(sessionId),
    });
  }

  void leave(String sessionId, String room) =>
      _leave(sessionId, room, notifySelf: true);

  void message(String sessionId, String room, String text) {
    if (!_isMember(sessionId, room)) return;
    _toRoom(room, 'message', {
      'room': room,
      'from': nameOf(sessionId),
      'text': text,
    });
  }

  void typing(String sessionId, String room) {
    if (!_isMember(sessionId, room)) return;
    _toOthers(room, sessionId, 'typing', {
      'room': room,
      'user': nameOf(sessionId),
    });
  }

  void _leave(String sessionId, String room, {required bool notifySelf}) {
    final members = _rooms[room];
    if (members == null || !members.remove(sessionId)) return;
    if (notifySelf) _send(sessionId, 'left', {'room': room});
    _toOthers(room, sessionId, 'user-left', {
      'room': room,
      'user': nameOf(sessionId),
    });
    if (members.isEmpty) _rooms.remove(room);
  }

  bool _isMember(String sessionId, String room) =>
      _rooms[room]?.contains(sessionId) ?? false;

  List<String> _roomsOf(String sessionId) => _rooms.entries
      .where((e) => e.value.contains(sessionId))
      .map((e) => e.key)
      .toList();

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
}
