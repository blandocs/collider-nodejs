module.exports =

if process.env.NODE_ENV is "product"
  product_constants = 
    'MODE' : 'product mode'
    'PORT' : 8089
    'WSS_TLS' : true
else
  develop_constants = 
    'MODE' : 'develop mode'
    'PORT' : 8089
    'WSS_TLS' : false