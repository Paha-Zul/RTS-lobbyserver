import ws, options, utils, sugar, sequtils

type
    User* = ref object
        ws*:WebSocket
        name*:string

    UserList* = ref object
        users:seq[User]

proc newUserList*():UserList = 
    return UserList(users: newSeq[User]())

proc getUserBySocket*(users:UserList, ws:WebSocket):Option[User] = 
    return users.users.first(u => u.ws == ws)

proc getUserByName*(users:UserList, name:string):Option[User] = 
    return users.users.first(u => u.name == name)
    
proc getUser*[User](users:UserList, pred: proc (x: User): bool {.closure.}) {.inline.} =
    return users.users.first(pred)

proc removeUserBySocket*(users:UserList, ws:WebSocket) = 
    users.users = users.users.filter(u => u.ws != ws)

proc removeUserByName*(users:UserList, name:string) = 
    users.users = users.users.filter(u => u.name != name)

proc removeUser*[User](users:UserList, pred: proc (x: User): bool {.closure.}) {.inline.} =
    users.users = users.users.filter(pred)

proc addUser*(users:UserList, ws:Websocket, name:string) =
    users.users.add User(ws: ws, name: name)

proc getUsers*(users:UserList):seq[User] =
    return users.users