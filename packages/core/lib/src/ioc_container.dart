typedef FactoryFunc<T> = T Function();

/// Service container.
class IoCContainer {
  static final IoCContainer _instance = IoCContainer._internal();
  factory IoCContainer() => _instance;
  IoCContainer._internal();

  final Map<Type, dynamic> _singletons = {};
  final Map<Type, FactoryFunc<dynamic>> _factories = {};

  final Map<Type, dynamic> _defaults = {};

  final Set<Type> _resolving = {};

  /// Registers [factory] as the implementation of [T].
  ///
  /// With `singleton: true` the factory runs once, immediately, and every
  /// resolution returns that instance. Otherwise it runs per resolution.
  void register<T>(FactoryFunc<T> factory, {bool singleton = false}) {
    if (singleton) {
      _singletons[T] = factory();
    } else {
      _factories[T] = factory;
    }
  }

  /// Registers an already-constructed [instance] as the implementation
  /// of [T].
  void registerInstance<T>(T instance) {
    _singletons[T] = instance;
  }

  /// Returns the registered implementation of [T].
  ///
  /// Throws when [T] has neither a registration nor a default. A service
  /// resolving itself should use [resolveOrDefault] instead.
  T resolve<T>() {
    final resolved = _tryResolve<T>();
    if (resolved != null) return resolved;

    final existing = _defaults[T];
    if (existing != null) return existing as T;

    throw Exception(
      'Service of type $T is not registered in the IoC container.',
    );
  }

  /// Returns the registered implementation of [T], falling back to
  /// [ifAbsent] — built once and reused.
  T resolveOrDefault<T>(FactoryFunc<T> ifAbsent) {
    final resolved = _tryResolve<T>();
    if (resolved != null) return resolved;

    final existing = _defaults[T];
    if (existing != null) return existing as T;

    return _guard<T>(() {
      final created = ifAbsent();
      _defaults[T] = created;
      return created;
    });
  }

  /// Drops any registration and default for [T], so the next resolution
  /// rebuilds from the service's own default.
  void reset<T>() {
    _singletons.remove(T);
    _factories.remove(T);
    _defaults.remove(T);
  }

  /// Drops every registration and default.
  void resetAll() {
    _singletons.clear();
    _factories.clear();
    _defaults.clear();
    _resolving.clear();
  }

  /// True when [T] has a registration or a built default.
  bool isRegistered<T>() =>
      _singletons.containsKey(T) ||
      _factories.containsKey(T) ||
      _defaults.containsKey(T);

  T? _tryResolve<T>() {
    if (_singletons.containsKey(T)) return _singletons[T] as T;
    final factory = _factories[T];
    if (factory != null) return _guard<T>(() => factory() as T);
    return null;
  }

  /// Runs [build] while tracking [T] as in-flight, so a factory that
  /// resolves its own type — directly or through another service —
  /// reports a cycle instead of overflowing the stack.
  T _guard<T>(FactoryFunc<T> build) {
    if (!_resolving.add(T)) {
      throw Exception(
        'Circular dependency detected while resolving $T. '
        'Resolution chain: ${_resolving.join(' -> ')} -> $T',
      );
    }
    try {
      return build();
    } finally {
      _resolving.remove(T);
    }
  }
}
