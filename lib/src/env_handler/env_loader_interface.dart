import 'dart:io';

abstract class IEnvLoader {
  Map<String, String> loadEnvFile({File? file});
}
