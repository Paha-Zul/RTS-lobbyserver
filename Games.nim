import tables, options, ws, sequtils

type
    Game* = ref object
        name*:string
        id*:int64
        maxPlayers*:int8
        currPlayers*:int8
        password*:string
        hidden*:bool
        hostIP*:string
        hostName*:string
        websocket*:WebSocket

    # A simplified data object of Game
    # should be used when sending data through sockets
    GameData* = object
        name*:string
        id*:int64
        maxPlayers*:int8
        currPlayers*:int8
        password*:string
        hidden*:bool
        hostIP*:string
        hostName*:string

    GameTable* = object
        gamesTable: TableRef[int64, Game]
    
proc newGameTable*(): GameTable =
    return GameTable(gamesTable: newTable[int64, Game](64))

proc addGameToTable*(table:GameTable, game:Game) = 
    table.gamesTable[game.id] = game

proc removeGameFromTable*(table:GameTable, gameId:int64) =
    table.gamesTable.del gameId

proc removeGameFromTable*(table:GameTable, game:Game) =
    table.removeGameFromTable(game.id)

proc getGameFromTable*(table:GameTable, gameId:int64):Option[Game] =
    let game = table.gamesTable.getOrDefault(gameId)
    if game == nil:
        return none(Game)
    else:
        return some(game)

proc hasGameId*(table:GameTable, gameId:int64):bool =
    return table.gamesTable.hasKey(gameId)

proc getGameList*(table:GameTable):seq[Game] =
    seqUtils.toSeq(table.gamesTable.values)