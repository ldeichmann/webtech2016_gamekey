import 'dart:convert';
import 'dart:io' ;
import 'package:start/start.dart';
import 'dart:math';
import 'dart:async';
import 'package:crypto/crypto.dart';

/// Enables Cross origin by editing the response header
void enableCors(Response response){
    response.header("Access-Control-Allow-Origin",
        "*"
    );
    response.header("Access-Control-Allow-Methods",
        "POST, GET, DELETE, PUT, OPTIONS"
    );
    response.header("Access-Control-Allow-Headers",
        "Origin, Content-Type, Accept, Charset"
        );
}

///Gets game by id
///
/// returns null if game not found
Map get_game_by_id(String id, Map memory) {
    for(Map m in memory['games']){
        if(m['id'].toString()==id.toString()) return m;
    }
    return null;
}

///Looks for existing game by id
///
/// returns false if not found
bool game_exists(String name, Map memory){
    for(Map m in memory['games']){
        if(m['name'] == name) return true;
    }
    return false;
}

///Gets user by name
///
/// returns null if user not found
Map get_user_by_name(String name, Map memory){
    for(Map m in memory['users']){
        if(m['name'] == name) return m;
    }
}

///Gets user by id
///
/// returns null if user not found
Map get_user_by_id(String id, Map memory){
    for(Map m in memory['users']){
        if(m['id'].toString() == id.toString()) return m;
    }
}

///Looks for existing user by id
///
/// returns false if not found
bool user_exists(String name, Map memory){
    for(Map m in memory['users']){
        if(m['name'] == name) return true;
    }
    return false;
}

///Control if E-Mail is correct
///
/// returns false if E-Mail has no Match with RegExp
bool isEmail(String em) {
    String p = r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
    RegExp regExp = new RegExp(p);
    return regExp.hasMatch(em);
}

///Control if Url is correct
///
/// returns false if Url has no Match with RegExp
bool isUrl(String url){
    String exp = r'(https?:\/\/)';
    RegExp regExp = new RegExp(exp);
    return regExp.hasMatch(url);
}

///Authentication
///
/// returns true if Authentication failed or false if Authentic
bool isNotAuthentic(Map user, String pwd){
    if(user['signature']!= BASE64.encode((sha256.convert(UTF8.encode(user["id"].toString() + ',' + pwd))).bytes))return true;
    return false;
}

main() async{
    ///Template for json file
    Map DB = {
        'service' : "Gamekey",
        'version':    "0.0.1",
        'users':      [],
        'games':      [],
        'gamestates': []
    };
    Map memory ;
    File file = new File('\gamekey.json');
    ///Test if gamekey already hast data
    if(!await file.exists() || (await file.length() < DB.length)) {
        file.openWrite().write(JSON.encode(DB));
    }
    ///initialize Memory with gamekey.json
    memory = JSON.decode(await file.readAsString());
    start(host: '0.0.0.0',port: 8080).then((Server app) {
        app.static('web');
        ///Gets Users
        ///
        /// returns all Users
        app.get('/users').listen((request){
            Response res = request.response;
            enableCors(res);
            res.status(HttpStatus.OK).json(memory["users"]);
        });

        ///Posts one User
        ///
        /// returns created User if succesful
        app.post('/user').listen((request) async{
            ///enabling cors
            Response res = request.response;
            enableCors(res);
            ///Parameters
            String name;
            String pwd;
            var mail;
            var id = new Random.secure().nextInt(0xFFFFFFFF);
            ///Reading payload from request
            //Request req = request;
            if(request.input.headers.contentLength != -1) {
                var map = await request.payload();
                name = map["name"];
                pwd = map["pwd"];
                mail = map["mail"];
            }

            ///Test if required params are given
            if(name == null){
                res.status(HttpStatus.BAD_REQUEST).send("Bad Request: Name is required");
                return null;
            }

            if(pwd == null){
                res.status(HttpStatus.BAD_REQUEST).send("Bad Request: Password is required");
                return null;
            }
            ///Test if Mail is valid
            if(mail != null) {
                if (!isEmail(mail)) {
                    res.status(HttpStatus.BAD_REQUEST).send(
                        "Bad Request: $mail is not a valid email.");
                    return null;
                }
            }
            ///Test if user already exists
            if(user_exists(name, memory)){
                res.status(HttpStatus.CONFLICT).send("Bad Reqeust: The name $name is already taken");
                return null;
            }
            ///creating user with parameters
            var user = {
            'type'       : "user",
            'name'       : name,
            'id'         : id.toString(),
            'created'    : (new DateTime.now().toUtc().toIso8601String()),
            'mail'       : (mail != null)?mail:'',
            'signature'  : BASE64.encode(sha256.convert(UTF8.encode(id.toString() + ',' + pwd)).bytes)
            };
            memory["users"].add(user);
            file.openWrite().write(JSON.encode(memory));
            res.status(HttpStatus.OK).json(user);
        });

        ///Gets User by Id
        ///
        ///returns user if user exists
        app.get('/user/:id').listen((request) async{
            ///Enabling Cors
            Response res = request.response;
            enableCors(res);
            ///Initializing Params
            var id = request.param("id");
            var pwd = request.param("pwd");
            String byname = request.param("byname");
            if(request.input.headers.contentLength != -1){
                var map = await request.payload();
                pwd = map["pwd"]==null?"":map["pwd"];
                byname = map["byname"]==null?"":map["byname"];
            }
            Map user;
            ///Test if byname is correct
            if(!(byname.isEmpty) && (byname != 'true') && (byname != 'false')) {
                res.status(HttpStatus.BAD_REQUEST).send("Bad Request: byname parameter must be 'true' or 'false' (if set), was $byname.");
                return null;
            }
            if(byname == 'true'){
                user = get_user_by_name(id, memory);
            }
            if(byname == 'false' || byname.isEmpty) {
                user = get_user_by_id(id, memory);
            }
            if(user == null) {
                res.status(HttpStatus.NOT_FOUND).send(
                    "User not Found.");
                return null;
            }
            if(isNotAuthentic(user,pwd)){
                //print("unauthorized");
                res.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }
            ///Cloning user and adding alle played games and gamestates
            user = new Map.from(user);
            user['games'] = new List();
            if(memory['gamestates'] != null) {
                for (Map m in memory['gamestates']) {
                    if (m['userid'].toString() == user["id"].toString()) {
                        user['games'].add(m['gameid']);
                    }
                }
            }
            res.status(HttpStatus.OK).send(JSON.encode(user));
        });

        ///Puts user by id
        ///
        /// returns updated user if succesfull
        app.put('/user/:id').listen((request) async{
            ///Enabling Cors
            Response res = request.response;
            enableCors(res);
            ///Initializing params
            String id = request.param("id");
            String pwd;
            String new_name;
            String new_mail;
            String new_pwd;
            if(request.input.headers.contentLength != -1) {
                var map = await request.payload();
                pwd = map["pwd"] == null ? "" : map["pwd"];
                new_name = map["name"] == null ? "" : map["name"];
                new_mail = map["mail"] == null ? "" : map["mail"];
                new_pwd = map["newpwd"] == null ? "" : map["newpwd"];
            }

            ///Testing if isMail is correct
            if(!isEmail(new_mail) && !new_mail.isEmpty){
                res.status(HttpStatus.BAD_REQUEST).send("Bad Request: $new_mail is not a valid email.");
                return null;
            }
            ///Testing if user exist
            if(user_exists(new_name, memory)){
                res.status(HttpStatus.NOT_ACCEPTABLE).send("User with name $new_name exists already.");
                return null;
            }

            var user = get_user_by_id(id, memory);

            if(isNotAuthentic(user,pwd)){
                res.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }

            if(new_name != null)user['name'] = new_name;
            if(new_mail != null)user['mail'] = new_mail;
            if(new_pwd != null || !new_pwd.isEmpty)user['signature'] = BASE64.encode((sha256.convert(UTF8.encode(id.toString() + ',' + new_pwd.toString()))).bytes);
            user['update'] = new DateTime.now().toUtc().toIso8601String();
            file.openWrite().write(JSON.encode(memory));

            res.status(HttpStatus.OK).json(user);
        });

        app.delete('/user/:id').listen((request) async{
            ///Enabling Cors
            Response res = request.response;
            enableCors(res);
            ///Initializing params
            ///Erinnerung bei allen Requests params abfange bevor payload auslesen
            var id = request.param("id");
            var pwd = request.param("pwd");
            if(request.input.headers.contentLength != -1) {
                var map = await request.payload();
                pwd = map["pwd"] == null ? "" : map["pwd"];
            }

            var user = get_user_by_id(id, memory);

            if(user == null) {
                res.status(HttpStatus.OK).send(
                    "User not found.");
                return null;
            }

            if(isNotAuthentic(user,pwd)){
                res.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }
            if(memory['users'].remove(user)==null){
                request.response.send('Failed\n$user');
            }
            /*
            for(Map m in memory['gamestates']){
                if(m['userid'] == user["id"]){
                    memory['gamestates'].remove(m);
                }
            }*/

            List<Map> gs = new List<Map>();
            memory['gamestates'].where((g) => g["userid"].toString() == id.toString()).forEach((g) => gs.add(g));
            gs.forEach((g) => memory["gamestates"].remove(g));
            file.openWrite().write(JSON.encode(memory));
            res.status(HttpStatus.OK).send('Succes\n$user');
        });

        app.get('/games').listen((request){
            Response res = request.response;
            enableCors(res);
            res.send(JSON.encode(memory['games']));
        });

       app.post('/game').listen((request) async{
           Response res = request.response;
           enableCors(res);
           print("Bin in Post game");
            String name   = request.param('name');
            var secret = request.param('secret');
            String url    = request.param('url');
            if(request.input.headers.contentLength != -1) {
                var map = await request.payload();
                if(name.isEmpty)name = map["name"] == null ? "" : map["name"];
                if(secret.isEmpty)secret = map["secret"] == null ? "" : map["secret"];
                if(url.isEmpty)url = map["url"] == null ? "" : map["url"];
            }
            var id = new Random.secure().nextInt(0xFFFFFFFF);
            if(name == null || name.isEmpty){
                res.send('Game must be given a name');
            }
            Uri uri = Uri.parse(url);
            if(uri != null || !url.isEmpty){
                if(uri.isAbsolute) {
                    res.status(HttpStatus.BAD_REQUEST).send("Bad Request: '" + url +
                        "' is not a valid absolute url");
                    return null;
                }
            }
            //RegExp exp = new RegExp("http[s]?:.*.[A-Za-z1-9]+[.].*");
            if(!url.isEmpty && !isUrl(url)){
                res.status(HttpStatus.BAD_REQUEST).send("Bad Request: '" + url + "' is not a valid absolute url");
                return null;
            }
            if(!memory['games'].isEmpty) {
                    if(game_exists(name,memory)){
                        res.status(HttpStatus.BAD_REQUEST).send(
                            "Game Already exists");
                        return null;
                    }
            }
            Map game = {
            "type"      : 'game',
            "name"      : name,
            "id"        : id.toString(),
            "url"       : uri.toString(),
            "signature" : BASE64.encode((sha256.convert(UTF8.encode(id.toString() + ',' + secret.toString()))).bytes),
            "created"   : new DateTime.now().toUtc().toIso8601String()
            };
            try{
            memory['games'].add(game);} catch(e){print("games du nutte");}
            file.openWrite().write(JSON.encode(memory));
            res.status(HttpStatus.OK).send(JSON.encode(game));
        });
        
        app.get('/game/:id').listen((request) async{
            Response res = request.response;
            enableCors(res);
            var secret = request.param('secret');
            var id = request.param('id');
            if(request.input.headers.contentLength != -1) {
                var map = await request.payload();
                if(secret.isEmpty)secret = map["secret"] == null ? "" : map["secret"];
            }
            var game = get_game_by_id(id,memory);
            if(game == null){
                res.status(HttpStatus.NOT_FOUND).send("Game not found");
                return null;
            }
            game = new Map.from(game);
            if(BASE64.encode((sha256.convert(UTF8.encode(id.toString() + ',' + secret.toString()))).bytes) != game['signature']){
                res.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }
            game['users'] = new List();
            if(memory['gamestates'] != null) {
                for (Map m in memory['gamestates']) {
                    if (m['gameid'].toString() == id.toString()) {
                        game['users'].add(m['userid']);
                    }
                }
            }
            res.status(HttpStatus.OK).send(JSON.encode(game));
        });

         app.put('/game/:id').listen((request) async{
             Response res = request.response;
             enableCors(res);
            var id         = request.param('id');
            var secret     = request.param('secret');
            var new_name   = request.param('name');
            var new_url    = request.param('url');
            var new_secret = request.param('newsecret');
            if(request.input.headers.contentLength != -1) {
                var map = await request.payload();
                if(new_name.isEmpty)new_name = map["name"] == null ? "" : map["name"];
                if(secret.isEmpty)secret = map["secret"] == null ? "" : map["secret"];
                if(new_url.isEmpty)new_url = map["url"] == null ? "" : map["url"];
                if(new_secret.isEmpty)new_secret = map["newsecret"] == null ? "" : map["newsecret"];
            }

            Uri uri = Uri.parse(new_url);
            var game = get_game_by_id(id,memory);
            //print("ID:" + id + " Secret:" + secret + " NewName:" + new_name + " NewUrl:" + new_url + " NewSecret:" + new_secret);
            //print("Url:$new_url");
            //print("Url !empty ?:" + (!new_url.isEmpty).toString());
            //print("Url is Url ?:" + (!isUrl(new_url)).toString());
            //print("Url is uri?:" + (!uri.isAbsolute).toString());
            if(!new_url.isEmpty && (!isUrl(new_url))){
                res.status(HttpStatus.BAD_REQUEST).send("Bad Request: '" + new_url + "' is not a valid absolute url");
                return null;
            }

            if(new_name != null){
                if(game_exists(new_name,memory)){
                    print("Jo is here");
                    res.status(HttpStatus.BAD_REQUEST).send(
                        "Game Already exists");
                    return null;
                }
            }
            if(BASE64.encode((sha256.convert(UTF8.encode(id.toString() + ',' + secret.toString()))).bytes) != game['signature'].toString()){
                res.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }
            if(new_name != null)game['name'] = new_name;
            if(new_url != null)game['url'] = new_url;
            if(new_secret != null)game['signature'] = BASE64.encode((sha256.convert(UTF8.encode(id.toString() + ',' + new_secret.toString()))).bytes);
            game['update'] = new DateTime.now().toUtc().toString();
            file.openWrite().write(JSON.encode(memory));
             res.status(HttpStatus.OK).send(JSON.encode(game));
        });

        app.delete('/game/:id').listen((request) async{
            Response res = request.response;
            enableCors(res);
            var id         = request.param('id');
            var secret     = request.param('secret');
            if(request.input.headers.contentLength != -1) {
                var map = await request.payload();
                if(secret.isEmpty)secret = map["secret"] == null ? "" : map["secret"];
            }

            var game = get_game_by_id(id, memory);

            if(game == null){
                res.status(HttpStatus.OK).send("Game not found");
                return null;
            }
            if(BASE64.encode((sha256.convert(UTF8.encode(id.toString() + ',' + secret.toString()))).bytes) != game['signature']){
                res.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }

            if(memory['games'].remove(game)==null){
                res.status(HttpStatus.OK).send('Failed\n$game');
            }
            /*
            for(Map m in memory['gamestates']){
                if(m['gameid'] == game["id"]){
                    memory['gamestates'].remove(m);
                }
            }*/
            print("Delete states");
            List<Map> gs = new List<Map>();
            memory['gamestates'].where((g) => g["gameid"].toString() == id.toString()).forEach((g) => gs.add(g));
            gs.forEach((g) => memory["gamestates"].remove(g));
            file.openWrite().write(JSON.encode(memory));

            res.status(HttpStatus.OK).send('Succes\n$game');
        });

        app.get('/gamestate/:gameid/:userid').listen((request) async{
            Response res = request.response;
            enableCors(res);
            print("Bin in get gamestate/userid");
            var gameid = request.param('gameid');
            var userid = request.param('userid');
            var secret = request.param('secret');
            if(request.input.headers.contentLength != -1) {
                var map = await request.payload();
                if(secret.isEmpty)secret = map["secret"] == null ? "" : map["secret"];
            }

            var game = get_game_by_id(gameid, memory);
            var user = get_user_by_id(userid, memory);
            print("allo");

            if(user == null || game == null){
                res.status(HttpStatus.NOT_FOUND).send(
                    "User or game NOT Found.");
                return null;
            }

            if(game['signature'] != BASE64.encode((sha256.convert(UTF8.encode(gameid.toString() + ',' + secret.toString()))).bytes)){
                res.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }
            var states = new List<Map>();
            for(Map m in memory['gamestates']){
               if(m['gameid'].toString() == gameid.toString() && m['userid'].toString() == userid.toString()){
                    var state = new Map.from(m);
                    state["gamename"] = game["name"];
                    state["username"] = user["name"];
                    states.add(state);
               }
            }
            states.sort((m,n) => DateTime.parse(n["created"]).compareTo(DateTime.parse(m["created"])));
            res.status(HttpStatus.OK).send(JSON.encode(states));
        });

        app.get('/gamestate/:gameid').listen((request) async{
            Response res = request.response;
            enableCors(res);
            print("Bin in get gamstate/gameid");
            var gameid = request.param('gameid');
            var secret = request.param('secret');
            if(request.input.headers.contentLength != -1) {
                var map = await request.payload();
                if(secret.isEmpty)secret = map["secret"] == null ? "" : map["secret"];
            }

            var game = get_game_by_id(gameid, memory);

            if(game == null){
                res.status(HttpStatus.NOT_FOUND).send(
                    "Game NOT Found.");
                return null;
            }

            if(!game['signature'].toString() == BASE64.encode((sha256.convert(UTF8.encode(gameid.toString() + ',' + secret.toString()))).bytes)){
                res.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }
            var states = new List();
            for(Map m in memory['gamestates']){
                if(m['gameid'].toString() == gameid.toString()){
                    states.add(m);
                }
            }
            res.status(HttpStatus.OK).json(states.toString());
        });

        app.post('/gamestate/:gameid/:userid').listen((request) async{
            Response res = request.response;
            enableCors(res);
            print("Bin in post gamestate");
            var gameid = request.param('gameid');
            var userid = request.param('userid');
            var secret = request.param('secret');
            var state  = request.param('state');
            if(request.input.headers.contentLength != -1) {
                var map = await request.payload();
                if(secret.isEmpty)secret = map["secret"] == null ? "" : map["secret"];
                if(state.isEmpty)state = map["state"] == null ? "" : map["state"];
            }
            print("Gameid:" + gameid + " Userid:" + userid + " Secret:" + secret + " state:" + state);
            var game   = get_game_by_id(gameid, memory);
            var user   = get_user_by_id(userid, memory);
            print(game);
            print(user);

            if(user == null || game == null){
                res.status(HttpStatus.NOT_FOUND).send(
                    "User or game NOT Found.");
                return null;
            }

            if(game['signature'].toString() != BASE64.encode((sha256.convert(UTF8.encode(gameid.toString() + ',' + secret.toString()))).bytes)){
                res.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }

            try{

            state = JSON.decode(state);

            if(state == null || state.toString().isEmpty){
                request.response.status(HttpStatus.BAD_REQUEST).send(
                    "Bad request: state must not be empty, was $state");
                return null;
            }

            var gamestate = {
                "type"    : 'gamestate',
                "gameid"  : gameid,
                "userid"  : userid,
                "created" : (new DateTime.now().toUtc().toIso8601String()),
                "state"   : state
             };
             print("state:" + gamestate.toString());
             memory['gamestates'].add(gamestate);
             file.openWrite().write(JSON.encode(memory));
             res.status(HttpStatus.OK).json(gamestate);
            } on NoSuchMethodError catch(e){
                print(e);
                res.status(HttpStatus.BAD_REQUEST).send('Bad request: state must be provided as valid JSON, was $state');
            }
        });
    });
}
