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
querystring = require 'querystring'

# support client side (probaly have to not use request.js)
# might need to clone options

defaults =
  timeout: process.env.EPIQUERY_TIMEOUT ? 1000 * 60 * 5
  server: process.env.EPIQUERY_SERVER ? "http://localhost:7070"
  username: process.env.EPIQUERY_USER ? ""
  password: process.env.EPIQUERY_PASS ? ""
  retries: process.env.EPIQUERY_RETRIES ? 5
  backoff: process.env.EPIQUERY_BACKOFF ? 5
  assumeMustache: true

# constructor and main entry point, if the first parameter is an object, its options
epiquery = module.exports = (pathOrDefaults, json={}, options={}) ->
  if typeof pathOrDefaults is 'object'
    defaults = _.defaults pathOrDefaults, defaults
    debug "defaults now", defaults
    epiquery
  else
    epiquery.post pathOrDefaults, json, options

# verb specific convenience methods
epiquery.get = (path, params, options) -> sendRequest "GET", path, params, options
epiquery.post = (path, json, options) -> sendRequest "POST", path, json, options

sendRequest = (method, path, json={}, options={}) ->
  options = _.defaults options, defaults
  # assume mustache if extension is missing
  path = "#{path}.mustache" if Path.extname(path) is '' and options.assumeMustache

  # trim leading/trailing slashes to match expectations
  path = if path.slice 0 is '/' then path.slice 0 else path
  server = if options.server.slice -1 is '/' then options.server.slice 0, -1 else options.server
  uri = "#{options.server}/#{path}"

  requestOptions =
    uri: uri
    auth:
      username: options.username
      password: options.password
    method: method
    timeout: options.timeout
    json: json
    gzip: true

  if method is "POST"
    requestOptions.json = json
    debug "POSTing to #{uri}", json
  if method is "GET"
    requestOptions.json = true
    requestOptions.qs = json
    debug "GETing #{uri}?#{querystring.stringify requestOptions.qs}"

  retry ->
    requestAsync requestOptions
  , { max_tries: options.retries, backoff: options.backoff }
  .then (response) ->
    if response.statusCode isnt 200
      debug "Unexpected Epiquery Response: ", response.body
      throw new Error "Unexpected HTTP response: #{response.statusCode}"
    results = if typeof response.body is 'string' then JSON.parse resonse.body else response.body
    debug "Received #{results.length} records like these:"
    debug _.first results
    results

epiquery.proxy = (options) ->
  options = _.defaults options, defaults
  router.all '/*', proxy
    url: "#{options.server}/*"
    headers:
      Authorization: "Basic #{new Buffer("#{options.username}:#{options.password}").toString 'base64'}"
  
epiquery.healthcheck = ->
  epiquery "diagnostic", {}, { assumeMustache: false }
  .then (response) ->
    console.log "Successfully connected to #{defaults.server} for Epiquery".blue
    response
