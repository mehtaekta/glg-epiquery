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
_.str = require 'underscore.string'

module.exports = (defaults={}) ->
  client = new EpiqueryClient defaults

  epiquery = (path, args, options) ->
    client.post path, args, options
  epiquery.get = client.get
  epiquery.post = client.post
  epiquery.proxy = client.proxy
  epiquery.healthcheck = client.healthcheck
  return epiquery

camelize = (row) ->
  _.reduce(row, (acc, v, k) ->
    key = _.str.camelize(k.toLowerCase())
    acc[key] = v;
    acc
  , {})

camelizeAll = (obj) ->
  if _.isPlainObject(obj)
    camelize(obj)
  else if _.isArray(obj)
    return _.each obj, (row, i, k) -> obj[i] = camelizeAll(row)
  else
    return obj

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

    # trim leading slash from path if present
    path = if path.slice(0, 1) is '/' then path.slice(1) else path
    
    # trim trailing slash from server URL if present
    server = if options.server.slice(-1) is '/' then options.server.slice(0, -1) else options.server

    # handle epiquery2
    if options.connection?
      uri = "#{server}"
      uri += "/#{options.apiKey}" if options.apiKey?
      uri += "/epiquery1/#{options.connection}/#{path}"
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
        debug "Unexpected Epiquery Response: "
        debug response.body
        bodytext = if typeof response.body is 'object' then JSON.stringify response.body else response.body
        throw new Error "Unexpected HTTP response at #{requestOptions.uri}: #{response.statusCode}, #{bodytext}"
      results = if typeof response.body is 'string' then JSON.parse response.body else response.body
      results = camelizeAll(results) if json.camelizeResults
      # It's possible for results to be undefined under epiquery2 if no results are returned,
      # so be sure to soak it here.
      debug "Received #{results?.length} records", if results?.length isnt 0 then "First record:" else ""
      debug _.first results if results?.length isnt 0
      results

  proxy: (options) =>
    options = _.defaults options, @defaults
    debug "creating epiquery proxy with options"
    debug options
    router.all '/*', expressRequestProxy
      url: "#{options.server}/*"
      timeout: options.timeout
      headers:
        Authorization: "Basic #{new Buffer("#{options.username}:#{options.password}").toString 'base64'}"

  healthcheck: =>
    @get "diagnostic", {}, { assumeMustache: false }
    .then (response) =>
      console.log "Successfully connected to #{@defaults.server} for Epiquery".blue
      response
