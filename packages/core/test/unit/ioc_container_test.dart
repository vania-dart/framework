import 'package:test/test.dart';
import 'package:vania/src/cache/cache.dart';
import 'package:vania/src/config/config.dart';
import 'package:vania/src/ioc_container.dart';

class _Plain {
  final String tag;
  _Plain(this.tag);
}

class _StubConfig implements Config {
  @override
  dynamic get(String key) => 'stub:$key';

  @override
  set setApplicationConfig(Map<String, dynamic> conf) {}

  @override
  T? typed<T>(String key, [T? defaultValue]) => defaultValue;

  @override
  T required<T>(String key) => throw UnimplementedError();
}

void main() {
  tearDown(() {
    IoCContainer().reset<_Plain>();
    IoCContainer().reset<Config>();
    IoCContainer().reset<Cache>();
  });

  group('registration', () {
    test('a factory registration runs per resolution', () {
      var built = 0;
      IoCContainer().register<_Plain>(() => _Plain('${built++}'));

      expect(IoCContainer().resolve<_Plain>().tag, equals('0'));
      expect(IoCContainer().resolve<_Plain>().tag, equals('1'));
    });

    test('a singleton registration builds once', () {
      var built = 0;
      IoCContainer().register<_Plain>(() {
        built++;
        return _Plain('once');
      }, singleton: true);

      final a = IoCContainer().resolve<_Plain>();
      final b = IoCContainer().resolve<_Plain>();

      expect(identical(a, b), isTrue);
      expect(built, equals(1));
    });

    test('registerInstance returns exactly that object', () {
      final instance = _Plain('mine');
      IoCContainer().registerInstance<_Plain>(instance);

      expect(identical(IoCContainer().resolve<_Plain>(), instance), isTrue);
    });

    test('resolving an unregistered type throws', () {
      expect(() => IoCContainer().resolve<_Plain>(), throwsException);
    });
  });

  group('defaults', () {
    test('resolveOrDefault builds the fallback once', () {
      var built = 0;
      _Plain make() {
        built++;
        return _Plain('default');
      }

      final a = IoCContainer().resolveOrDefault<_Plain>(make);
      final b = IoCContainer().resolveOrDefault<_Plain>(make);

      expect(identical(a, b), isTrue);
      expect(built, equals(1));
    });

    test('a registration takes precedence over the default', () {
      IoCContainer().registerInstance<_Plain>(_Plain('override'));

      expect(
        IoCContainer().resolveOrDefault<_Plain>(() => _Plain('default')).tag,
        equals('override'),
      );
    });

    test('reset drops the override and the default', () {
      IoCContainer().registerInstance<_Plain>(_Plain('override'));
      IoCContainer().reset<_Plain>();

      expect(
        IoCContainer().resolveOrDefault<_Plain>(() => _Plain('default')).tag,
        equals('default'),
      );
    });
  });

  group('framework services resolve through the container', () {
    test('Cache() returns the same instance every time', () {
      expect(identical(Cache(), Cache()), isTrue);
    });

    test('overriding a service changes what plain call sites get', () {
      expect(Config().get('anything'), isNot(equals('stub:anything')));

      IoCContainer().registerInstance<Config>(_StubConfig());

      expect(Config().get('anything'), equals('stub:anything'));
    });

    test('resetting restores the real implementation', () {
      IoCContainer().registerInstance<Config>(_StubConfig());
      expect(Config().get('anything'), equals('stub:anything'));

      IoCContainer().reset<Config>();

      expect(Config().get('anything'), isNot(equals('stub:anything')));
    });

    test('createDefault builds an instance outside the container', () {
      final isolated = Config.createDefault();
      isolated.setApplicationConfig = {'scoped': true};

      expect(isolated.get('scoped'), isTrue);
      expect(
        Config().get('scoped'),
        isNull,
        reason: 'an isolated instance must not touch the shared one',
      );
    });
  });

  group('circular dependencies', () {
    test('a factory resolving its own type reports a cycle', () {
      IoCContainer().register<_Plain>(() => IoCContainer().resolve<_Plain>());

      expect(
        () => IoCContainer().resolve<_Plain>(),
        throwsA(
          predicate(
            (e) => e.toString().contains('Circular dependency detected'),
          ),
        ),
      );
    });
  });
}
