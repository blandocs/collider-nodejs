WebSocketServer = require('websocket').server
http = require('http')
logger = require('tracer').console()
utf8 = require('utf8')

server = http.createServer((request, response) ->
  console.log new Date + ' Received request for ' + request.url

  if request.url.match(/\d\/\d/)

    request_split = request.url.split('/')
    
    if request_split.length isnt 3
      logger.log "Invalid path"
      response.writeHead 404
      response.end()
      return
    rid = request_split[1]
    cid = request_split[2]
    
    response.setHeader("Access-Control-Allow-Origin", '*')
    response.setHeader("Access-Control-Allow-Methods", 'POST, DELETE')

    body = ""

    if request.method is 'POST'
      request.on 'data', (chunk) ->
        body += chunk

      request.on 'end', () ->
        logger.log 'body: ' + body
        jsonObj = JSON.parse(body)

        logger.log body
        if body is ""
          response.writeHead 500
          response.write("Empty request body")
          response.end()
          logger.log "Empty request body"
          return
        else 
          logger.log collider.roomTable.send(rid, cid, body) 
          if collider.roomTable.send(rid, cid, body) is true
            response.writeHead 200
            response.end()    
            return
          else
            response.writeHead 500
            response.end()
            return

    else
      response.writeHead 500
      response.end()
      return

  else
    response.writeHead 404
    response.end()
    return
)

maxQueuedMsgCount = 1024

class Client

  constructor: (id) ->
    @id = id # string
    @wsc = null # ws connection
    @msg = [] # string array
    
  register: (wsc) ->
    if @wsc isnt null
      logger.log "duplicate register"
      return false
    else
      @wsc = wsc
      logger.log "ok"
      return true

  deregister: () ->
    @wsc.close()
    @wsc = null

  registered: () ->
    return @wsc isnt null

  enqueue: (msg) ->
    if @msg.length >= maxQueuedMsgCount
      logger.log "too many queued msg"
      return false
    @msg.push(msg)
    return true

  sendQueued: (other) ->
    logger.log "sendQueued"
    if (@id is other.id) or other.wsc is null
      logger.log "Invalid client"
      return false
    for m in @msg
      logger.log m
      await sendServerMsg defer other.wsc, m
    @msg = []
    logger.log "Sent queued messages from #{@id} to #{other.id}"
    return true

  send: (other, msg) ->
    if (@id is other.id) 
      logger.log "Invalid client"
      return false
    if (other.wsc isnt null)
      logger.log msg
      sendServerMsg other.wsc, msg
      return true
    else
      logger.log "enqueue in client send"
      return @enqueue(msg)
      # @msg.push(msg)
      # return true

maxRoomCapacity = 2

class Room

  constructor: (roomTable, id, rs) ->
    @parent = roomTable # roomTable
    @id = id # ws connection
    @clients = {} #  A mapping from the client ID to the client object. key: string, value client object
    @roomSrvUrl = rs
  client: (clientID) ->
    c = @clients[clientID]

    if c isnt undefined then return c


    if Object.keys(@clients).length >= maxRoomCapacity
      logger.log "Room #{@id} is full, not adding client #{clientID}"
      return false

    @clients[clientID] = new Client(clientID)


    logger.log "Added client #{clientID} to room #{@id}"
    return @clients[clientID]

    # register fail -> remove client frmo room table

  register: (clientID, wsc) ->

    client = @client(clientID)
    
    # logger.log wsc
    
    if client is false
      return false

    if client.register(wsc) is false
      return false

    logger.log client.id

    logger.log "Client #{clientID} registered in room #{@id}"

    logger.log Object.keys(@clients).length

    if Object.keys(@clients).length > 1

      for c_id in Object.keys(@clients)
        logger.log c_id
        @clients[c_id].sendQueued(client)
    return true

  send: (srcClientID, msg) ->
    src = @client(srcClientID)
    # logger.log src
    if src is false
      return false    


    if Object.keys(@clients).length is 1
      logger.log "enqueue in room send"
      @clients[srcClientID].enqueue(msg)

    logger.log Object.keys(@clients).length

    for c_id in Object.keys(@clients)
      logger.log c_id
      if c_id isnt srcClientID
        logger.log c_id
        return src.send(@clients[c_id], msg)

  remove: (clientID) ->
    client = @client(clientID)

    if client
      client.deregister()
      delete @clients[clientID]
      logger.log "Removed client #{clientID} from room @id"

      # Send bye to the room Server.
      # resp, err := http.Post(rm.roomSrvUrl+"/bye/"+rm.id+"/"+clientID, "text", nil)
      # if err != nil {
      #   log.Printf("Failed to post BYE to room server %s: %v", rm.roomSrvUrl, err)
      # }
      # if resp != nil && resp.Body != nil {
      #   resp.Body.Close()
      # }

  empty: () ->
    return Object.keys(@clients).length is 0

  wsCount: () ->
    count = 0
    for c_id in Object.keys(@clients)
      if @client[c_id].registered()
        count += 1

    return count 

class RoomTable

  constructor: (rs) ->
    @rooms = {} #  A mapping from the room ID to the room object. key: string, value room object
    @roomSrvUrl = rs

  room: (id) ->
    return @roomLocked(id)
  roomLocked: (id) ->
    r = @rooms[id]
    if r
      return r
    @rooms[id] = new Room(@, id, @roomSrvUrl)
    logger.log "Created room #{id}"
    return @rooms[id]

  remove: (rid, cid) ->
    @removeLocked(rid, cid)

  removeLocked: (rid, cid) ->
    r = @rooms[rid]

    if r isnt null
      r.remove(cid)
      if r.empty()
        delete @rooms[rid]
        logger.log "Removed room #{rid}"

  send: (rid, srcID, msg) ->
    r= @roomLocked(rid)
    return r.send(srcID, msg)

  register: (rid, cid, wsc) ->
    r= @roomLocked(rid)
    return r.register(cid, wsc)

  deregister: (rid, cid) ->
    r = @rooms[rid]

    if r isnt null
      c = r.clients[cid]
      if c isnt null
        if c.registered()
          c.deregister()

          # c.setTimer(time.AfterFunc(rt.registerTimeout, func() {
          #   rt.removeIfUnregistered(rid, c)
          # }))

          logger.log "Deregistered client #{c.id} from room #{rid}"
          return

  # removeIfUnregistered

  wsCount: () ->
    count = 0
    for r_id in Object.keys(@rooms)
      count += @rooms[r_id].wsCount()

    return count

class wsClientMsg

  constructor: (json_object) ->
    json_object = JSON.parse(json_object)

    @Cmd = json_object.cmd
    @RoomID = json_object.roomid
    @ClientID = json_object.clientid
    @Msg = json_object.msg

class wsServerMsg

  constructor: (msg, err) ->
    logger.log msg
    @Msg = msg
    @Error = err


sendServerMsg = (wsc, msg) ->
  logger.log msg
  m = new wsServerMsg(msg, null)
  logger.log m
  return send(wsc, m.Msg)

sendServerErr = (wsc, err) ->
  m = new wsServerMsg(null, err)
  return send(wsc, m.Error)

send = (wsc, msg) ->
  logger.log  utf8.encode(msg)
  wsc.sendUTF utf8.encode(JSON.stringify({msg: msg}))

class Collider

  constructor: (rs) ->
    @roomTable = new RoomTable(rs)



originIsAllowed = (origin) ->
  # put logic here to detect whether the specified origin is allowed. 
  true

collider = new Collider("http://127.0.0.1:8000")



server.listen 8089, ->
  console.log new Date + ' Server is listening on port 8089'
  return
 

wsServer = new WebSocketServer(
  httpServer: server
  autoAcceptConnections: false)

wsServer.on 'request', (request) ->
  if !originIsAllowed(request.origin)
    # Make sure we only accept requests from an allowed origin 
    request.reject()
    console.log new Date + ' Connection from origin ' + request.origin + ' rejected.'
    return
  # console.log request.socket
  connection = request.accept(null, request.origin)
  console.log new Date + ' Connection accepted.'

  connection.on 'message', (message) ->
    if message.type is 'utf8'
      # console.log connection
      console.log 'Received Message: ' + message.utf8Data

      ClientMsg = new wsClientMsg(message.utf8Data)
      
      cmd = ClientMsg.Cmd

      if connection.rid is undefined
        rid = ClientMsg.RoomID
      else
        rid = connection.rid
      if connection.cid is undefined
        cid = ClientMsg.ClientID
      else
        cid = connection.cid
      msg = ClientMsg.Msg

      # logger.log ClientMsg
      logger.log rid
      logger.log cid
      # logger.log rid

      if cmd is "register"
        if connection.registered
          logger.log "Duplicated register request"
          return

        if rid is "" or cid is "" 
          logger.log "Invalid register request: missing 'clientid' or 'roomid'"
          return

        result = collider.roomTable.register(rid, cid, connection)
        # logger.log connection
        if result is false
          return

        connection.registerd = true
        connection.rid = rid
        connection.cid = cid

        # collider.roomTable.deregister(rid, cid)

      else if cmd is "send"
        if connection.registered is false
          logger.log "Client not registered"
          return  

        if msg is ""
          logger.log "Invalid send request: missing 'msg'"
          return

        collider.roomTable.send(rid, cid, msg)
        return
      else
        logger.log "Invalid message: unexpected 'cmd'"
        return


      # connection.sendUTF message.utf8Data
    else if message.type is 'binary'
      console.log 'Received Binary Message of ' + message.binaryData.length + ' bytes'
      connection.sendBytes message.binaryData
    return

  connection.on 'close', (reasonCode, description) ->
    console.log new Date + ' Peer ' + connection.remoteAddress + ' disconnected.'
    return
  return
