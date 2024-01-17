import 'package:vania/src/container.dart';
import 'package:vania/src/server/base_http_server.dart';
import 'package:vania/vania.dart';

class Application extends Container{
  static Application? _singleton;

  factory Application() {
    _singleton ??= Application._internal();
    return _singleton!;
  }

  Application._internal();

  BaseHttpServer get server => BaseHttpServer();


  void initialize({required Map<String,dynamic> config }) async{
    
    Config().setApplicationConfig = config;


    List<ServiceProvider> provider = config['providers'];

    for(ServiceProvider provider in provider){
      provider.register();
    }

    DatabaseDriver db = Config().get('database').driver;
    await db.init();

    server.startServer(host: config['host'], port: config['port']);
  }


}