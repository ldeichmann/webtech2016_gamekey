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

bool game_exists(String name, Map memory){
    for(Map m in memory['games']){
        if(m['name'] == name) return true;
    }
    return false;
}

Map get_user_by_name(String name, Map memory){
    for(Map m in memory['users']){
        if(m['name'] == name) return m;
    }
}

Map get_user_by_id(String id, Map memory){
    for(Map m in memory['users']){
        if(m['id'].toString() == id.toString()) return m;
    }
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

bool isAuthentic(Map user, String pwd){
    if(user['signature']!= BASE64.encode(UTF8.encode(user['name'] + pwd)))return true;
    return false;
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
    if(!await file.exists() || (await file.length() < DB.length)) {
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
            'type'       : "user",
            'name'       : request.param('name'),
            'id'         : id,
            'created'    : (new DateTime.now()).toString(),
            'mail'       : mail,
            'signature'  : BASE64.encode(UTF8.encode(name + pwd))
            };
            memory["users"].add(user);
            file.openWrite().write(JSON.encode(memory));
            request.response.send(JSON.encode(user));
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
                    "User not Found.");
                return null;
            }
            if(isAuthentic(user,pwd)){
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

            var user = get_user_by_id(id, memory);

            if(isAuthentic(user,pwd)){
                request.response.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }

            if(new_name != null)user['name'] = new_name;
            if(new_mail != null)user['mail'] = new_mail;
            if(new_pwd != null)user['signature'] = BASE64.encode(UTF8.encode(new_name + new_pwd));
            user['update'] = new DateTime.now().toString();
            file.openWrite().write(JSON.encode(memory));

            request.response.send('Succes\n$user');
        });

        app.delete('/user/:id').listen((request){
            var id = request.param('id');
            var pwd = request.param('pwd');

            var user = get_user_by_id(id, memory);

            if(user == null) {
                request.response.status(HttpStatus.NOT_FOUND).send(
                    "Userer not Found.");
                return null;
            }

            if(isAuthentic(user,pwd)){
                request.response.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }

            if(memory['users'].remove(user)==null){
                request.response.send('Failed\n$user');
            }
            file.openWrite().write(JSON.encode(memory));

            request.response.send('Succes\n$user');
        });

        app.get('/games').listen((request){
            request.response.send(JSON.encode(memory['games']));
        });

       app.post('/game').listen((request){
            String name   = request.param('name');
            var secret = request.param('secret');
            String url    = request.param('url');
            var id = new Random.secure().nextInt(0xFFFFFFFF);
            if(name == null || name.isEmpty){
                request.response.send('Game must be given a name');
            }
            Uri uri = Uri.parse(url);
            if(uri == null || url.isEmpty){
                request.response.send("Bad Request: '" + url + "' is not a valid absolute url");
            }
            RegExp exp = new RegExp("http[s]?:.*.[A-Za-z1-9]+[.].*");
            if(!exp.hasMatch(url)){
                request.response.send("Bad Request: '" + url + "' is not a valid absolute url");
            }
            if(memory['games'].isEmpty) {
                for (Map m in memory['games']){
                    if(memory['games'] == name){
                        request.response.send("Bad Request: Game already exist");
                    }
                }
            }
            Map game = {
            "type"      : 'game',
            "name"      : name,
            "id"        : id,
            "url"       : uri.toString(),
            "signature" : BASE64.encode(UTF8.encode(id.toString() + secret.toString())),
            "created"   : (new DateTime.now()).toString()
            };
            memory['games'].add(game);
            file.openWrite().write(JSON.encode(memory));
            request.response.send(JSON.encode(game));
        });
        
        app.get('/game/:id').listen((request){
            var secret = request.param('secret');
            var id = request.param('id');
            var game = get_game_by_id(id,memory);
            if(game == null){
                request.response.send("Game not found");
            }
            if(BASE64.encode(UTF8.encode(id + secret)).toString() != game['signature']){
                request.response.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
            }
            for(Map m in memory['gamestate']) {
                if (m['gameid'].toString() == id.toString()) {
                    game['users'].add(m['userid']);
                }
            }
            request.response.send(JSON.encode(game));
        });

         app.put('/game/:id').listen((request){
            var id         = request.param('id');
            var secret     = request.param('secret');
            var new_name   = request.param('name');
            var new_url    = request.param('url');
            var new_secret = request.param('newsecret');
            Uri uri = Uri.parse(new_url);
            var game = get_game_by_id(id,memory);
            RegExp exp = new RegExp("http[s]?:.*.[A-Za-z1-9]+[.].*");
            if(!exp.hasMatch(new_url)){
                request.response.send("Bad Request: '" + new_url + "' is not a valid absolute url");
            }
            if(new_name != null){
                if(game_exists(new_name,memory)){
                    request.response.status(HttpStatus.BAD_REQUEST).send(
                        "Game Already exists");
                }
            }
            if(BASE64.encode(UTF8.encode(id + secret)).toString() != game['signature'].toString()){
                request.response.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
            }
            if(new_name != null)game['name'] = new_name;
            if(new_url != null)game['url'] = new_url;
            if(new_secret != null)game['signature'] = BASE64.encode(UTF8.encode(new_name + new_secret));
            game['update'] = new DateTime.now().toString();
            file.openWrite().write(JSON.encode(memory));
        });

        app.delete('/game/:id').listen((request){
            var id = request.param('id');
            var secret = request.param('secret');

            var game = get_game_by_id(id, memory);

            if(game == null){
                request.response.send("Game not found");
                return null;
            }
            if(BASE64.encode(UTF8.encode(id + secret)).toString() != game['signature']){
                request.response.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }

            if(memory['users'].remove(game)==null){
                request.response.send('Failed\n$game');
            }
            file.openWrite().write(JSON.encode(memory));

            request.response.send('Succes\n$game');
        });

        app.get('/gamestate/:gameid/:userid').listen((request){
            var gameid = request.param('gameid');
            var userid = request.param('userid');
            var secret = request.param('secret');

            var game = get_game_by_id(gameid, memory);
            var user = get_user_by_id(userid, memory);

            if(user == null || game == null){
                request.response.status(HttpStatus.NOT_FOUND).send(
                    "User or game NOT Found.");
                return null;
            }

            if(game['signature'].toString() != (BASE64.encode(UTF8.encode(gameid + secret))).toString()){
                request.response.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }
            Map states;
                for(Map m in memory['gamestates']){
                    if(m['gameid'].toString() == gameid.toString() && m['userid'].toString() == userid.toString()){
                        states.addAll(m);
                    }
                }
            return states.toString();
        });

        app.get('/gamestate/:gameid').listen((request) {
            var gameid = request.param('gameid');
            var secret = request.param('secret');

            var game = get_game_by_id(gameid, memory);

            if(game == null){
                request.response.status(HttpStatus.NOT_FOUND).send(
                    "Game NOT Found.");
                return null;
            }

            if(!game['signature'].toString() == (BASE64.encode(UTF8.encode(gameid + secret))).toString()){
                request.response.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }
            Map states;
            for(Map m in memory['gamestates']){
                if(m['gameid'].toString() == gameid.toString()){
                    states.addAll(m);
                }
            }
            return states.toString();
        });

        app.post('/gamestate/:gameid').listen((request) {
            var gameid = request.param('gameid');
            var userid = request.param('userid');
            var secret = request.param('secret');
            var state  = request.param('state');

            var game   = get_game_by_id(gameid, memory);
            var user   = get_user_by_id(userid, memory);

            if(user == null || game == null){
                request.response.status(HttpStatus.NOT_FOUND).send(
                    "User or game NOT Found.");
                return null;
            }

            if(!game['signature'].toString() == (BASE64.encode(UTF8.encode(gameid + secret))).toString()){
                request.response.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }

            state = JSON.decode(state);

            if(state == null || state.isEmpty){
                request.response.status(HttpStatus.BAD_REQUEST).send(
                    "Bad request: state must not be empty, was $state");
                return null;
            }

            try{
                Map gamestate={
                    "type"    : 'gamestate',
                    "gameid"  : gameid,
                    "userid"  : userid,
                    "created" : (new DateTime.now()).toString(),
                    "state"   : state
                };
                file.openWrite().write(JSON.encode(memory));
                request.response.send(JSON.encode(gamestate));
            }
            catch(e){
                print(e);
                request.response.status(HttpStatus.BAD_REQUEST).send('Bad request: state must be provided as valid JSON, was $state');
            }
        });
    });
}
