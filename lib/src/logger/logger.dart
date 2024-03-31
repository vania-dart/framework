// ignore_for_file: constant_identifier_names
import 'dart:io';
import '../utils/helper.dart';

class Logger {
  static const EMERGENCY = 'EMERGENCY';
  static const ALERT = 'ALERT';
  static const CRITICAL = 'CRITICAL';
  static const ERROR = 'ERROR';
  static const SUCCESS = 'SUCCESS';
  static const WARNING = 'WARNING';
  static const NOTICE = 'NOTICE';
  static const INFO = 'INFO';
  static const DEBUG = 'DEBUG';

  static log(String content, {String type = INFO,String fileName = 'vania'}){
    final now = DateTime.now();

    final directory = Directory(storagePath('framework/logs'));
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    final logFile = File('${directory.path}/$fileName.log');
    final fsSink = logFile.openWrite(mode: FileMode.append);

    var text =
        "[${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}]";
    text += ' $type: ';
    text += content;
    text += '\n';

    fsSink.write(text);
    fsSink.close();
  }
}
