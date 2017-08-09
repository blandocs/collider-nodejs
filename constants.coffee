module.exports =

if process.env.NODE_ENV is null or "develop"

  develop_constants = 
    'PORT' : 8089
    'WSS_TLS' : false
else if process.env.NODE_ENV is "product"
  product_constants = 
    'PORT' : 8089
    'WSS_TLS' : true