import 'package:test/test.dart';
import 'package:websocket_chat/chat/chat_hub.dart';

/// One captured outgoing event.
class Sent {
  final String to;
  final String event;
  final Object? payload;
  Sent(this.to, this.event, this.payload);
}

void main() {
  late List<Sent> sent;
  late ChatHub hub;

  setUp(() {
    sent = [];
    hub = ChatHub((to, event, payload) => sent.add(Sent(to, event, payload)));
  });

  Iterable<Sent> to(String session) => sent.where((s) => s.to == session);
  Iterable<Sent> events(String name) => sent.where((s) => s.event == name);

  test('connect sends the current room list', () {
    hub.createRoom('a', 'general');
    sent.clear();

    hub.connect('b');

    final rooms = to('b').firstWhere((s) => s.event == 'rooms');
    expect((rooms.payload as Map)['rooms'], contains('general'));
  });

  test('set-name is used in later notifications', () {
    hub.connect('a');
    hub.connect('b');
    hub.setName('a', 'Alice');
    hub.setName('b', 'Bob');
    hub.join('a', 'general');
    sent.clear();

    hub.join('b', 'general');

    final joined = events('user-joined').single;
    expect(joined.to, 'a');
    expect((joined.payload as Map)['user'], 'Bob');
  });

  test('create-room announces to everyone and joins the creator', () {
    hub.connect('a');
    hub.connect('b');
    hub.setName('a', 'Alice');

    hub.createRoom('a', 'gaming');

    expect(events('room-created').map((s) => s.to), containsAll(['a', 'b']));
    expect(hub.membersOf('gaming'), ['Alice']);
  });

  test('message reaches every member of the room', () {
    hub.connect('a');
    hub.connect('b');
    hub.setName('a', 'Alice');
    hub.join('a', 'general');
    hub.join('b', 'general');
    sent.clear();

    hub.message('a', 'general', 'hello everyone');

    final msgs = events('message').toList();
    expect(msgs.map((s) => s.to), containsAll(['a', 'b']));
    final payload = msgs.first.payload as Map;
    expect(payload['from'], 'Alice');
    expect(payload['text'], 'hello everyone');
  });

  test('message from a non-member is ignored', () {
    hub.connect('a');
    hub.join('a', 'general');
    hub.connect('b'); // b never joined
    sent.clear();

    hub.message('b', 'general', 'sneaky');

    expect(events('message'), isEmpty);
  });

  test('typing notifies others but not the sender', () {
    hub.connect('a');
    hub.connect('b');
    hub.join('a', 'general');
    hub.join('b', 'general');
    sent.clear();

    hub.typing('a', 'general');

    final typing = events('typing').toList();
    expect(typing, hasLength(1));
    expect(typing.single.to, 'b');
  });

  test('leave notifies remaining members', () {
    hub.connect('a');
    hub.connect('b');
    hub.setName('a', 'Alice');
    hub.join('a', 'general');
    hub.join('b', 'general');
    sent.clear();

    hub.leave('a', 'general');

    final left = events('user-left').single;
    expect(left.to, 'b');
    expect((left.payload as Map)['user'], 'Alice');
    expect(hub.membersOf('general'), isNot(contains('Alice')));
  });

  test('disconnect removes the user from every room and notifies', () {
    hub.connect('a');
    hub.connect('b');
    hub.setName('a', 'Alice');
    hub.join('a', 'general');
    hub.join('a', 'random');
    hub.join('b', 'general');
    sent.clear();

    hub.disconnect('a');

    expect(events('user-left').map((s) => s.to), contains('b'));
    expect(hub.rooms, isNot(contains('random'))); // empty room is cleaned up
    expect(hub.membersOf('general'), ['anonymous']); // b, who set no name
  });
}
