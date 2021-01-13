import json
import Games

proc gameCreationAvailable*(id:int64):JsonNode =
    return %* {"action": "game_creation_available", "game_id": id}

# A message to be send directly to the user who requested a game to be created
proc gameCreatedSuccess*(game:GameData):JsonNode  =
    return %* {"action": "game_creation_success", "game_data": game}

# A message to be broadcast to all connected about a game created
proc gameCreated*(game:GameData):JsonNode  =
    return %* {"action": "game_created", "game_data": game}

proc gameClosed*(gameID:int64):JsonNode  =
    return %* {"action": "game_closed", "game_id": gameID}

proc userConnected*(gameList:JsonNode):JsonNode = 
    return %* {"action": "connected", "game_list": gameList}

proc gameJoinable*(hostIP:string, gameId:int64):JsonNode =
    return %* {"action": "game_joinable", "host_ip": hostIP, "game_id": gameId}

proc playerJoinedGame*(game:GameData):JsonNode =
    return %* {"action": "player_joined_game", "game_data": game}

proc playerLeftGame*(game:GameData):JsonNode =
    return %* {"action": "player_left_game", "game_data": game}

proc sendGameList*(gameList:GameData):JsonNode =
    return %* {"action": "game_list", "game_list": gameList}