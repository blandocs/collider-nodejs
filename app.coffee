WebSocketServer = require('websocket').server
http = require('http')
logger = require('tracer').console()

server = http.createServer((request, response) ->
  console.log new Date + ' Received request for ' + request.url
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
      return true

  deregister: () ->
    rwc.Close()
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
      await sendServerMsg defer other.wsc, m
      return true
    else
      return @enqueue(msg)
      # @msg.push(msg)
      # return true

class Room

  constructor: (roomTable, id, rs) ->
    @parent = roomTable # roomTable
    @id = id # ws connection
    @clients = {} #  A mapping from the client ID to the client object. key: string, value client object
    @roomSrvUrl = rs
  client: (clientID) ->
    c = @client[clientID]
    if c isnt null then return c

    if Object.keys(@clients).length >= maxRoomCapacity
      logger.log "Room #{@id} is full, not adding client #{clientID}"
      return false

    @clients[clientID] = new Client(clientID)

    logger.log "Added client #{clientID} to room #{@id}"
    return @clients[clientID]

    # register fail -> remove client frmo room table

  register: (clientID, wsc) ->
    client = @client(clientID)
    if client is false
      return false

    if client.register(wsc) is false
      return false

    logger.log "Client #{clientID} registered in room #{@id}"

    if Object.keys(@clients).length > 1
      for c_id, c_obj in @clients
        c_obj.sendQueued(client)
    return true

  send: (srcClientID, msg) ->
    src = @client(srcClientID)
    if src is false
      return false    

    if Object.keys(@clients).length is 1
      @clients[srcClientID].enqueue(msg)

    for c_id, c_obj in @clients 
      if c_id isnt srcClientID
        return src.send(c_obj, msg)

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
    for c_id, c_obj in @clients
      if c_obj.registered()
        count += 1

    return count 



originIsAllowed = (origin) ->
  # put logic here to detect whether the specified origin is allowed. 
  true

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
      console.log connection
      console.log 'Received Message: ' + message.utf8Data

      cmd = message.utf8Data.cmd
      roomid = message.utf8Data.roomid
      clientid = message.utf8Data.clientid

      connection.sendUTF message.utf8Data
    else if message.type is 'binary'
      console.log 'Received Binary Message of ' + message.binaryData.length + ' bytes'
      connection.sendBytes message.binaryData
    return

  connection.on 'close', (reasonCode, description) ->
    console.log new Date + ' Peer ' + connection.remoteAddress + ' disconnected.'
    return
  return
