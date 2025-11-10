typedef FactoryFunc<T> = T Function();

class IoCContainer {
  static final IoCContainer _instance = IoCContainer._internal();
  factory IoCContainer() => _instance;
  IoCContainer._internal();

  final Map<Type, dynamic> _singletons = {};
  final Map<Type, FactoryFunc<dynamic>> _factories = {};

  void register<T>(FactoryFunc<T> factory, {bool singleton = false}) {
    if (singleton) {
      _singletons[T] = factory();
    } else {
      _factories[T] = factory;
    }
  }

  T resolve<T>() {
    if (_singletons.containsKey(T)) {
      return _singletons[T];
    } else if (_factories.containsKey(T)) {
      return _factories[T]!() as T;
    }
    throw Exception(
      'Service of type $T is not registered in the IoC container.',
    );
  }
}
