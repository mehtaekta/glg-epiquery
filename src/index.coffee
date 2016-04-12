Promise = require 'bluebird'
requestAsync = Promise.promisify require 'request'
retry = require 'bluebird-retry'
_ = require 'lodash'
colors = require 'colors'
debug = require('debug') 'epiquery'
express = require 'express'
expressRequestProxy = require 'express-request-proxy'
router = module.exports = express.Router()
Path = require 'path'
querystring = require 'querystring'

module.exports = (defaults={}) ->
  client = new EpiqueryClient defaults
  
  epiquery = (path, args, options) ->
    client.post path, args, options
  epiquery.get = client.get
  epiquery.post = client.post
  epiquery.proxy = client.proxy
  return epiquery

class EpiqueryClient
  constructor: (options={}) ->
    return new EpiqueryClient options unless this instanceof EpiqueryClient
    
    @defaults = _.defaults options,
      timeout: process.env.EPIQUERY_TIMEOUT ? 1000 * 60 * 5
      server: process.env.EPIQUERY_SERVER ? "http://localhost:7070"
      username: process.env.EPIQUERY_USER ? ""
      password: process.env.EPIQUERY_PASS ? ""
      retries: process.env.EPIQUERY_RETRIES ? 5
      backoff: process.env.EPIQUERY_BACKOFF ? 5
      assumeMustache: true
      apiKey: process.env.EPISTREAM_APIKEY ? null
      connection: process.env.EPISTREAM_CONNECTION ? null

    debug "created new Epiquery Client with these defaults"
    debug @defaults
    console.log "Using #{@defaults.server} for epiquery".blue
    
  get: (path, params, options) =>
    @sendRequest "GET", path, params, options
  
  post: (path, json, options) =>
    @sendRequest "POST", path, json, options

  sendRequest: (method, path, json={}, options={}) =>
    options = _.defaults options, @defaults
    # assume mustache if extension is missing
    path = "#{path}.mustache" if Path.extname(path) is '' and options.assumeMustache

    # trim leading/trailing slashes to match expectations
    path = if path.slice 0 is '/' then path.slice 0 else path
    server = options.server
    # this below here don't work
    # if options.server.slice -1 is '/' then options.server.slice 0, -1 else options.server
    if options.connection?
      uri = "#{server}/#{options.apiKey}/epiquery1/#{options.connection}/#{path}"
    else
      uri = "#{server}/#{path}"
      
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
      debug "POSTing to #{uri}"
      debug json
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
      results = if typeof response.body is 'string' then JSON.parse response.body else response.body
      debug "Received #{results.length} records", if results.length isnt 0 then "First record:" else ""
      debug _.first results if results.length isnt 0
      results

  proxy: (options) =>
    options = _.defaults options, @defaults
    debug "creating epiquery proxy with options"
    debug options
    router.all '/*', expressRequestProxy
      url: "#{options.server}/*"
      headers:
        Authorization: "Basic #{new Buffer("#{options.username}:#{options.password}").toString 'base64'}"
  
  healthcheck: =>
    epiquery "diagnostic", {}, { assumeMustache: false }
    .then (response) ->
      console.log "Successfully connected to #{@defaults.server} for Epiquery".blue
      response
