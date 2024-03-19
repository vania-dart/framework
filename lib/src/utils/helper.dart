import 'dart:io';

String storagePath(String file) => '${Directory.current.path}/storage/$file';

String publicPath(String file) => '${Directory.current.path}/public/$file';
