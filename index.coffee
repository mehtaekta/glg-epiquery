Promise = require 'bluebird'
requestAsync = Promise.promisify require 'request'
retry = require 'bluebird-retry'
_ = require 'lodash'
colors = require 'colors'
debug = require('debug') 'epiquery'
express = require 'express'
proxy = require 'express-request-proxy'
router = module.exports = express.Router()
Path = require 'path'

# support client side (probaly have to not use request.js)
# might need to clone options

defaults =
  timeout: 1000 * 60 * 5
  server: process.env.EPIQUERY_SERVER ? "http://localhost:7070"
  username: process.env.EPIQUERY_USER ? ""
  password: process.env.EPIQUERY_PASS ? ""
  retries: 5
  backoff: 5

epiquery = module.exports = (path, json={}, options={}) ->
  # if the first parameter is an object, its options
  if typeof path is 'object'
    defaults = _.defaults defaults, options
    debug "defaults now", defaults
  else
    epiquery.post path, json, options

epiquery.get = (path, params, options) -> request "GET", path, params, options

epiquery.post = (path, json, options) -> request "POST", path, json, options
    
request = (method, path, json={}, options={}) ->
  options = _.defaults defaults, options
  path = "#{path}.mustache" if Path.extname(path) is ''

  # trim leading/trailing slashes to match expectations
  path = if path.slice 0 is '/' then path.slice 0 else path
  server = if options.server.slice -1 is '/' then options.server.slice 0, -1 else options.server
  uri = "#{options.server}/#{path}"

  debug "Posting to #{uri}", json
  retry ->
    requestAsync
      uri: uri
      auth:
        username: options.username
        password: options.password
      method: method
      timeout: options.timeout
      json: json
  , { max_tries: options.retries, backoff: options.backoff }
  .then (response) ->
    if response.statusCode isnt 200
      debug "Unexpected Epiquery Response: ", response 
      throw new Error "Unexpected HTTP response: #{response.statusCode}"
    debug "Received #{response.body.length} records like these:"
    debug _.first response.body
    response.body

epiquery.proxy = (options) ->
  options = _.defaults defaults, options
  router.all '/*', proxy
    url: "#{options.server}/*"
    headers:
      Authorization: "Basic #{new Buffer("#{options.username}:#{options.password}").toString 'base64'}"
  
epiquery.healthcheck = ->
  epiquery.get "diagnostic"
  .then (response) ->
    console.log "Connected to #{defaults.server} for Epiquery"
