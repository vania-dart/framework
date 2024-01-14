import 'dart:io';
import 'package:uuid/v4.dart';

Future webSocketHandler(HttpRequest req) async{
  WebSocket websocket = await WebSocketTransformer.upgrade(req);

  String id  = 'ws:${UuidV4()}';

  websocket.listen((message) {
    
  }, onDone: () {
    
  }, onError: (error) {
    
  });

}