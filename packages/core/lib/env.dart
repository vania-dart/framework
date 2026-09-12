import 'src/env_handler/env.dart' show Env;

export 'src/env_handler/env.dart' show Env;

T env<T>(String key, [dynamic defaultValue]) => Env.get<T>(key, defaultValue);
