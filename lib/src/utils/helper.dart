import 'dart:io';

import 'package:vania/vania.dart';

String storagePath(String file) => '${Directory.current.path}/storage/$file';

String publicPath(String file) => '${Directory.current.path}/public/$file';

T env<T>(String key, [dynamic defaultValue]) => Env.get<T>(key, defaultValue);
