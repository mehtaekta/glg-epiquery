#!/usr/bin/env coffee

epiquery = require('../src/index.coffee')()
colors = require 'colors'
express = require 'express'
app = express()

if process.argv.length > 2
  port = process.argv[2]
else
  port = process.env.PORT or 1137

app.use '/epiquery', epiquery.proxy()

server = app.listen port, ->
  host = server.address().host or 'localhost'
  port = server.address().port
  console.log "Listening at http://#{host}:#{port}/epiquery".blue
