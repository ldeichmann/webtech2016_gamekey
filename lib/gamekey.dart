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

Map get_game_by_id(String id, Map memory) {
    for(Map m in memory['games']){
        if(m['id']==id) return m;
    }
    return null;
}

Map get_user_by_name(String name, Map memory){
    for(Map m in memory['users']){
        if(m['name'] == name) return m;
    }
    //print("homo");
}

Map get_user_by_id(String id, Map memory){
    for(Map m in memory['users']){
        if(m['id'].toString() == id.toString()) return m;
    }
   // print("homo");
}

bool user_exists(String name, Map memory){
    for(Map m in memory['users']){
        if(m['name'] == name) return true;
    }
    return false;
}

bool isEmail(String em) {
    String p = r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
    RegExp regExp = new RegExp(p);
    return regExp.hasMatch(em);
}

main() async{
   // Gamekey test = new Gamekey();

    Map DB = {
        'service' : "Gamekey",
        //'storage':    SecureRandom.uuid,
        'version':    "0.0.1",
        'users':      [],
        'games':      [],
        'gamestates': []
    };
    Map memory ;
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
            var id = new Random.secure().nextInt(0xFFFFFFFF);
            //print(name);
            //print(pwd);
            if(!isEmail(mail)){
                request.response.status(HttpStatus.BAD_REQUEST).send("Bad Request: $mail is not a valid email.");
                return null;
            }
            if(user_exists(name, memory)){
                request.response.status(HttpStatus.BAD_REQUEST).send("Bad Reqeust: The name $name is already taken");
                return null;
            }
            var user = {
            "type"    : 'user',
            "name"       : name,
            "id"         : id,
            "created"    : new DateTime.now(),
            "mail"       : mail,
            "signature"  : BASE64.encode(UTF8.encode(name + pwd))
            };
            memory["users"].add(user);
            request.response.send('Alles Klar!');
        });

        app.get('/user/:id').listen((request){
            String pwd = request.param('pwd');
            String id = request.param('id');
            String byname = request.param('byname');

            Map user;
            if(byname != null && byname!= 'true' && byname != 'false') {
                request.response.status(HttpStatus.BAD_REQUEST).send("Bad Request: byname parameter must be 'true' or 'false' (if set), was $byname.");
            }
            if(byname == 'true'){
                user = get_user_by_name(id, memory);
            }
            if(byname == 'false') {
                user = get_user_by_id(id, memory);
            }
            if(user == null) {
                request.response.status(HttpStatus.NOT_FOUND).send(
                    "Userer not Found.");
                return null;
            }
            if(user['signature']!= BASE64.encode(UTF8.encode(id + pwd))){
                request.response.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }
            user['games'] = memory['gamestates'];
 
            request.response.send(user.toString());
        });

        app.put('/user/:id').listen((request){
            String id       = request.param('id');
            String pwd      = request.param('pwd');
            String new_name = request.param('name');
            String new_mail = request.param('mail');
            String new_pwd  = request.param('newpwd');

            if(!isEmail(new_mail)){
                request.response.status(HttpStatus.BAD_REQUEST).send("Bad Request: $new_mail is not a valid email.");
                return null;
            }

            if(user_exists(new_name, memory)){
                request.response.status(HttpStatus.NOT_ACCEPTABLE).send("User with name $new_name exists already.");
                return null;
            }

            var user = get_game_by_id(id, memory);

            if(user['signature']!= BASE64.encode(UTF8.encode(id + pwd))){
                request.response.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }

            if(new_name != null)user['name'] = new_name;
            if(new_mail != null)user['mail'] = new_mail;
            if(new_pwd != null)user['signature'] = BASE64.encode(UTF8.encode(new_name + new_pwd));
            user['update'] = new DateTime.now();
        });
    });
}