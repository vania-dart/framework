

abstract class ServiceProvider {
  const ServiceProvider();
  Future<void> boot();
  Future<void> register();
}