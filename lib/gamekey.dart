import 'dart:convert';
import 'dart:io' ;
import 'package:start/start.dart';
import 'dart:math';

/*
class Gamekey{
    var storage;
    var port;
    var memory;
    var DB;

    Gamekey(){
    this.storage = "gamekey.json";
    this.port = 8080;
    this.DB = {
        service:    "Gamekey",
        storage:    SecureRandom.uuid,
        version:    "0.0.1",
        users:      [],
        games:      [],
        gamestates: []
    };
    File file = new File('/' + storage);
        if(file.existsSync()){

        }
}
}
*/

main() async{
   // Gamekey test = new Gamekey();
    Map DB = {
        'service' : "Gamekey",
        //'storage':    SecureRandom.uuid,
        'version':    "0.0.1",
        'users':      ['Peter', 'Rolf'],
        'games':      [],
        'gamestates': []
    };
    var memory ;
    File file = new File('\gamekey.json');
    if(!await file.exists()) {
        file.openWrite().write(JSON.encode(DB));
    }
    memory = JSON.decode(await file.readAsString());
    start(port: 8080).then((Server app) {
        app.static('web');
        app.get('/users').listen((request){
            String users = memory['users'].toString();
            request.response.send(users);
        });

        app.post('/user').listen((request){
            String name = request.param('name');
            String pwd = request.param('pwd');
            var mail = request.param('mail');
            var id = new Random.secure();
            print(name);
            print(pwd);
            var user = {
            "type"    : 'user',
            "name"       : name,
            "id"         : id,
            "created"    :"#{ Time.now.utc.iso8601(6) }",
            "mail"       : mail,
            "signature"  : BASE64.encode(UTF8.encode(name + pwd))
            };
            memory["users"].add(user);
            request.response.send('Alles Klar!');
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