#!/usr/bin/env coffee

epiquery = require '../index.coffee'

if process.argv.length > 2
  epiquery.post process.argv[2]
  .then (records) ->
    console.log JSON.stringify records, null, 2
else
  console.log "Usage: epiquery <template>"
