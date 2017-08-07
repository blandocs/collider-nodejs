WebSocketServer = require('websocket').server
http = require('http')

server = http.createServer((request, response) ->
  console.log new Date + ' Received request for ' + request.url
  response.writeHead 404
  response.end()
  return
)

registerTimeoutSec = 10
# This is a temporary solution to avoid holding a zombie connection forever, by
# setting a 1 day timeout on reading from the WebSocket connection.
wsReadTimeoutSec = 60 * 60 * 24


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
  console.log request
  connection = request.accept(null, request.origin)
  console.log new Date + ' Connection accepted.'

  connection.on 'message', (message) ->
    if message.type is 'utf8'
      console.log 'Received Message: ' + message.utf8Data
      connection.sendUTF message.utf8Data
    else if message.type is 'binary'
      console.log 'Received Binary Message of ' + message.binaryData.length + ' bytes'
      connection.sendBytes message.binaryData
    return

  connection.on 'close', (reasonCode, description) ->
    console.log new Date + ' Peer ' + connection.remoteAddress + ' disconnected.'
    return
  return
