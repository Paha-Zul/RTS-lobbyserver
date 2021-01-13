import ws, asyncdispatch, asynchttpserver, json, tables, sequtils, sugar, random, httpclient, options
import Messages, Games, Users, utils

const SERVER_PORT = 9002
const HIGHEST = 2147483647


randomize()

type
    User* = ref object
        ws:WebSocket
        name:string

    Context* = ref object
        gamesTable:GameTable
        users:UserList

var context = Context(gamesTable: Games.newGameTable(), users: Users.newUserList())

proc makeGameData(game:Game):GameData = 
    ## Makes a GameData object from a Game object
    return GameData(
            name: game.name,
            id: game.id,
            maxPlayers: game.maxPlayers,
            currPlayers: game.currPlayers,
            password: "",
            hidden: game.hidden,
            hostIP: "",
            hostName: game.hostName,
        )

proc closeGame(game:Game, context:Context) {.async, gcsafe.} =
    context.gamesTable.removeGameFromTable(game.id)
    let message = Messages.gameClosed(game.id)
    for pair in context.users.getUsers():
        if pair.ws.readyState == Open:
            asyncCheck pair.ws.send($message)

proc removeUser(ws:WebSocket, context:Context) {.async, gcsafe.} =
    # let name = socketTable[ws.key] # Get the name
    # let socketUserPair = connections.first(x => x.ws == ws)
    let socketUserPair = context.users.getUserBySocket(ws)
    # assert(socketUserPair.isNone, "The websocket disconnecting never fully connected")

    # socketTable.del name
    # connections = connections.filter(x => x.ws != ws)
    # context.users.removeUser(u => u.ws != ws)
    context.users.removeUserBySocket(ws)

    let games = context.gamesTable.getGameList()
    # We need to remove the game if there is one.
    let game = games.first(g => g.websocket == ws)
    if game.isSome:
        await closeGame(game.get, context)

    let name = if socketUserPair.isSome: socketUserPair.get.name else: ""
    echo "Removing " & name

proc getGameList(context:Context):seq[GameData] = 
    # Build our game data list to send to our connected player
    let gameDataList = context.gamesTable.getGameList()
            .filter(g => not g.hidden)
            .map(proc (g:Game):GameData =
                GameData(
                    name: g.name, # Set the name
                    id: g.id, # Set the game id
                    maxPlayers: g.maxPlayers,
                    currPlayers: g.currPlayers,
                    password: (if g.password == "": "false" else: "true"),
                    hidden: g.hidden,
                    hostName:g.hostName
                )
            )

    return gameDataList

proc handleConnected(data:JsonNode, ws:WebSocket, context:Context) {.async.} = 
    try:
        assert(data.hasKey("name"), "Incomplete data, missing name")

        # var connection = connections.first(x => x.ws == ws)
        # var connection = context.users.getUser(x => x.ws == ws)
        var connection = context.users.getUserBySocket(ws)
        if connection.isSome:
            connection.get.name = data["name"].getStr

        echo "User " & data["name"].getStr & " connected"

        let gameDataList = getGameList(context)
        let message = Messages.userConnected(%*gameDataList)

        # Send the data to the client
        if ws.readyState == Open:
            asyncCheck ws.send($message)


    except Exception:
        echo getCurrentExceptionMsg()

proc handleRequestGameList(data:JsonNode, ws:WebSocket, context:Context) {.async.} = 
    try:
        # Build our game data list to send to our connected player
        let gameDataList = getGameList(context)
        let message = Messages.userConnected(%*gameDataList)

        # Send the data to the client
        if ws.readyState == Open:
            asyncCheck ws.send($message)


    except Exception:
        echo getCurrentExceptionMsg()

proc handleRequestJoinGame(data:JsonNode, ws:WebSocket, context:Context) {.async, gcsafe.} =
    try:
        assert(data.hasKey("game_id"))

        # Get the game ID and the game
        let gameID = data["game_id"].getInt
        let game = context.gamesTable.getGameFromTable(gameID)

        # Make sure we have a game.
        # This is not asserted because there's no hard in trying to join a 
        # non-existent game
        if game.isSome:
            let g = game.get
            if g.currPlayers < g.maxPlayers: # If players aren't full
                let message = Messages.gameJoinable(g.hostIP, g.id) # Make the message
                if ws.readyState == Open: # Send our game data to the player
                    asyncCheck ws.send($message)
        else:
            echo "No game was found for id " & $gameID

    except AssertionError:
        echo "Data assertion failed"
        echo getCurrentExceptionMsg()


proc handleRequestCreateGame(data:JsonNode, ws:WebSocket, context:Context) {.async.} =
    try:
        # assert(data.hasKey(""))

        let id = rand(high(int)) # Make a random id for the game

        # TODO What heppens on a key clash? Retry?
        if not context.gamesTable.hasGameId(id):
            let success = Messages.gameCreationAvailable(id)
            if ws.readyState == Open:
                asyncCheck ws.send($success)
        else:
            echo "Games table already has key? " & $id
    
    except AssertionError:
        echo getCurrentExceptionMsg()

proc handleCreateGame(data:JsonNode, ws:WebSocket, context:Context) {.async, gcsafe.} =
    try:
        assert(data.hasKey("game_name"))
        assert(data.hasKey("password"))
        assert(data.hasKey("hidden"))
        assert(data.hasKey("max_players"))
        assert(data.hasKey("host_name"))
        assert(data.hasKey("host_ip"))

        let name = data["game_name"].getStr
        let hostName = data["host_name"].getStr
        let password = data["password"].getStr
        let hidden = data["hidden"].getBool
        let id = data["game_id"].getInt
        let hostIp = data["host_ip"].getStr
        let maxPlayers = int8(data["max_players"].getInt)

        let game = Game(
            name: name, # Set the name
            id: id, # Make random game id
            maxPlayers: maxPlayers,
            currPlayers: 1,
            password: password,
            hidden: hidden,
            hostName: hostName,
            websocket:ws,
            hostIP: hostIp
        )

        let gameData = GameData(
            name: name, # Set the name
            id: game.id, # Make random game id
            maxPlayers: maxPlayers,
            currPlayers: 1,
            password: password,
            hidden: hidden,
            hostName: hostName,
        )

        context.gamesTable.addGameToTable(game)

        let message = Messages.gameCreated(gameData)
        for pair in context.users.getUsers():
            if pair.ws.readyState == Open:
                asyncCheck pair.ws.send($message)

        let success = Messages.gameCreatedSuccess(gameData)
        if ws.readyState == Open:
            asyncCheck ws.send($success)

    except AssertionError:
        echo getCurrentExceptionMsg()
    except Exception:
        echo getCurrentExceptionMsg()

proc handlePlayerJoinedGame(data:JsonNode, ws:WebSocket, context:Context) {.async, gcsafe.} = 
    try:
        assert(data.hasKey("player_name"), "'player_name' is missing from data")
        assert(data.hasKey("game_id"), "'game_id' is missing from data")

        let playerName = data["player_name"].getStr
        let gameID = data["game_id"].getInt

        let game = context.gamesTable.getGameFromTable(gameID)
        if game.isSome :
            game.get.currPlayers += 1
            
            # Tell all connected players that a player joined
            let message = Messages.playerJoinedGame(makeGameData(game.get))
            for user in context.users.getUsers():
                if user.ws.readyState == Open:
                    asyncCheck user.ws.send($message)
        
    except AssertionError:
        echo "Assertion error"

proc handlePlayerLeftGame(data:JsonNode, ws:WebSocket, context:Context) {.async, gcsafe.} =
    try:
        assert(data.hasKey("player_name"), "'player_name' is missing from data")
        assert(data.hasKey("game_id"), "'game_id' is missing from data")

        let playerName = data["player_name"].getStr
        let gameID = data["game_id"].getInt

        let game = context.gamesTable.getGameFromTable(gameID)
        if game.isSome:
            game.get.currPlayers -= 1

            # Tell all connected players tha a user left
            let message = Messages.playerLeftGame(makeGameData(game.get))
            for user in context.users.getUsers():
                if user.ws.readyState == Open:
                    asyncCheck user.ws.send($message)

    except AssertionError:
        echo "Assertion error"

proc handleDestroyGame(data:JsonNode, ws:WebSocket, context:Context) {.async, gcsafe.} =
    try:
        assert(data.hasKey("game_id"), "'game_id' is missing from data")

        let gameID = data["game_id"].getInt

        let game = context.gamesTable.getGameFromTable(gameID)
        if game.isSome:
            await closeGame(game.get, context)

    except AssertionError:
        echo "Assertion error"

proc cb(req: Request) {.async, gcsafe.} =
    if req.url.path == "/ws/games":
        var ws = await newWebSocket(req) # Await a new connection

        try:
            # connections.add User(ws:ws, name:"") # Add half a pair to start
            context.users.addUser(ws, "")
            while ws.readyState == Open:
                let (opcode, data) = await ws.receivePacket()
                try:
                    let json = parseJson(data)
                    let action = json{"action"}.getStr()

                    echo data

                    case action:
                        of "connected": # A user has connected
                            await handleConnected(json, ws, context)
                        of "request_create_game": # A user is requesting to make a game
                            await handleRequestCreateGame(json, ws, context)
                        of "game_created": # A user has made a game (after requesting)
                            await handleCreateGame(json, ws, context)
                        of "request_join_game": # A user is requesting to join a specific game
                            await handleRequestJoinGame(json, ws, context)
                        of "player_joined_game": # A user has joined a game
                            await handlePlayerJoinedGame(json, ws, context)
                        of "player_left_game": # A user has left a game
                            await handlePlayerLeftGame(json, ws, context)
                        of "destroy_game":
                            await handleDestroyGame(json, ws, context)
                        of "request_game_list":
                            await handleRequestGameList(json, ws, context)

                except JsonParsingError:
                    echo "Parsing error on json"

        except WebSocketError:
            echo "socket closed:", getCurrentExceptionMsg()
            try:
                await removeUser(ws, context)
            except AssertionError:
                echo getCurrentExceptionMsg()
    else:
        await req.respond(Http404, "Not found")
        

echo "Server is started and waiting"

var server = newAsyncHttpServer()
waitFor server.serve(Port(SERVER_PORT), cb)