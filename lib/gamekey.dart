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

    app.get('/user/:id').listen((request){
      String pwd = request.params['pwd'];
      String id = request.params['id'];
      String byname = request.params['byname'];


      if(byname != null && byname!= 'true' && byname != 'false') {
        request.response.status(HttpStatus.BAD_REQUEST).send("Bad Request: byname parameter must be 'true' or 'false' (if set), was $byname.");
      }
    });
  });
}