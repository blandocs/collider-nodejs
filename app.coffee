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
      @msg.push(msg)
      return true




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
