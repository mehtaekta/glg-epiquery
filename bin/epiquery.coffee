#!/usr/bin/env coffee

epiquery = require '../src/index.coffee'
argv = require('minimist') process.argv.slice(2),

if process.argv.length > 2
  path = process.argv[2]
  payload = if process.argv.length > 3 then JSON.parse process.argv[3] else null
  epiquery path, payload
  .then (records) ->
    console.log JSON.stringify records, null, 2
else
  console.log "Usage: epiquery <template>"
