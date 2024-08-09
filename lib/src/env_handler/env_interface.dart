// Define an interface for environment configurations
abstract class IEnv {
  T get<T>(String key, [dynamic defaultValue]);
}
