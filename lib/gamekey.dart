import 'package:start/start.dart';
import 'dart:convert';
import 'dart:io' show HttpRequest, HttpStatus;

main(){
  start(port: 5000).then((Server app){
    app.static('web');

    app.get('/test').listen((request){
      request.response.send('Hallo');
    });

    app.post('/test').listen((request){
      request.response.send('Affe');
    });
  });
}