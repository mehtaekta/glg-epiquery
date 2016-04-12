# Epiquery Client

A promise oriented [epiquery](https://github.com/glg/epiquery) client built on [bluebird](https://github.com/petkaantonov/bluebird/) and [request.js](https://github.com/request/request) that sets everything up for you the way you'd expect and provides some handy conveniences. It uses GLG's starphleet ENV conventions for configuring the server credentials by default, so you probably don't need to do anything else. In addition to just working the epiquery client provides:

  * automatic retry, with progressive back off
  * integrated [debug](https://github.com/visionmedia/debug) logging
  * a proxy service middleware for express
  * configurable, increased request timeout
  * a simple command line version

To install, simply use the npm package manager
 
```shell
npm install --save glg/glg-epiquery
```

## Making Requests

Typically you will simply use the `epiquery()` method to POST a template and optional payload to the server. There are also two convenience methods, `epiquery.get()` and `epiquery.post()` if you prefer to be respectful of REST conventions. Each of these takes a template path relative to the epiquery server and an optional JSON object as its second parameter. In the case of `get()` the object is interpreted as a list of query string name/value pairs, rather than JSON payload.

Note that when importing the epiquery library, if you do not pass any configuration options you still need to execute the imported function with no arguments, as shown in the example below.

### Typical usage (CoffeeScript)

```coffee-script
epiquery = require('glg-epiquery')()

epiquery '/glgCurrentUser/getUserByEmail.mustache',
  email: 'dfields@glgroup.com'
.then (users) ->
  console.log "Hi there, #{users[0]}.firstName"
```

### Typical usage (JavaScript)

```javascript
var epiquery = require('glg-epiquery')();

epiquery('/glgCurrentUser/getUserByEmail.mustache', {
  email: 'dfields@glgroup.com'
}).then(function(users) {
  console.log("Hi there, " + users[0] + ".firstName");
});
```

Because I hate typing, you can omit the `.mustache` extension if you wish, it will be added for you.

## Failed Requests

This library will automatically retry requests that fail, with a progressive delay between failures. You can control the maximum number of retries, as well as the delay, via the configuration options. To disable this feature, simply set `retries` to 0.

If, after the maximum number of retries has been reached, or a request cannot otherwise be fulfilled, this library will throw an error, suitable for handling via bluebird's `.catch()` mechanism.

## Configuration Options

By default, the client uses the ENV variables `EPIQUERY_SERVER`, `EPIQUERY_USER`, and `EPIQUERY_PASSWORD` to locate the server. I none of these are set, it uses `http://localhost:7070`. This means there's typically no setup needed for deploying locally or on starphleet.

If you want to use something different for some reason, you can change these, and other parameters by passing in an options argument to the epiquery client when importing it. For example:

### Setting options (CoffeeScript)

```coffee-script
epiquery = require('glg-epiquery')
  server: "http://localhost:8088"
  timeout: 30
```

### Setting options (JavaScript)

```javascript
epiquery = require('glg-epiquery')({
  server: "http://localhost:8088",
  timeout: 30
});
```

The `get()` and `post()` methods also accept an options hash as the last argument, allowing you to override options on a per request basis.

### Available configuration options

| option    | description     | env variable | default value                 |
|---------- |-----------------|--------------|-------------------------------|
| server    | server url      | `EPIQUERY_SERVER`  | `http://localhost:7070` |
| username  | server username | `EPIQUERY_USER`    |  none                   |
| password  | server password | `EPIQUERY_PASSWORD`|  none                   |
| retries   | number of times to retry | `EPIQUERY_RETRIES` | 5 times |
| backoff   | progressive delay between retries, in seconds | `EPIQUERY_BACKOFF` | 5 seconds |
| timeout   | request timeout, in seconds | `EPIQUERY_TIMEOUT` | 5 minutes |
| connection| epiquery2 connection | EPISTREAM_CONNECTION | none |
| apiKey    | epiquery2 apiKey | EPISTREAM_APIKEY | none |

## Proxy service middleware

A middleware service based on [express-request-proxy](https://github.com/4front/express-request-proxy) is provided that makes it to proxy calls from an express server. This makes it simple for your client side apps to talk to epiquery via your service without worrying about passing the configuration or authentication information from server to client. Simply mount the middleware on a local route, and you are good to go with a single line of code. You can pass in configuration options as an optional argument to the `proxy()` call if you need to change anything. There's an [example proxy server](bin/proxy.coffee) in the bin folder.

Note that currently, the proxy does not support all of the same features. Notably, you can't leave off the .mustache extension, and it does not have the same level of logging.

### Setting up an epiquery proxy (CoffeeScript)

```coffee-script
epiquery = require('glg-epiquery')()
express = require 'express'
app = express()

app.use '/epiquery', epiquery.proxy()

app.listen 8080
```

### Setting up an epiquery proxy (JavaScript)

```javascript
var epiquery = require('glg-epiquery');
var express = require('express');
var app = express();

app.use('/epiquery', epiquery.proxy());
app.listen(8080);
```

## Epistream / Epiquery 2

You can make connections to an epiquery2 server by configuring the client with the `connection` and `apiKey` properties. This will use the non streaming interface and will convert all the records for you. There are also environment variables for each of these.

```coffeescript
datahub = require('glg-epiquery')
  server: process.env.EPISTREAM_SERVER
  connection: 'datahub'
```

## Epiquery from the command line

A simple command line version, simply called `epiquery` is provided. It takes a single required argument, the template path, an an optional second argument, a JSON payload string. It then pretty prints the JSON results to stdout. I might expand this functionality if it proves useful. There's also a command line version of the `proxy` server functionality.

```shell
$ bin/epiquery.coffee net-promoter-score/due_for_survey '{"limit":1}'

[
  {
    "person_id": 983968,
    "first_name": "Abhik",
    "last_name": "Das",
    "email": ".Cle@rousmorepatted.qux",
    "salesforce_id": "003U000000i2YEkIAM",
    "last_activity_date": "2015-12-11T10:27:34.930Z"
  }
]
```

## Integrated debugging

This library uses the [debug](https://github.com/visionmedia/debug) library to give you some useful debugging feedback, such as tracking request and responses and sampling the return response. To make anything show up you'll need to turn on the `epiquery` debugging via the `DEBUG` ENV variable like this:

```shell
$ export DEBUG=epiquery
$ bin/epiquery.coffee net-promoter-score/due_for_survey '{"limit":1}'

epiquery POSTing to http://localhost:7070/net-promoter-score/due_for_survey.mustache +0ms { limit: 1 }
epiquery Received 1 records like these: +398ms
epiquery { person_id: 983968, first_name: 'Abhik', last_name: 'Das', email: '.Cle@rousmorepatted.qux', salesforce_id: '003U000000i2YEkIAM', last_activity_date: '2015-12-11T10:27:34.930Z' } +1ms

[
  {
    "person_id": 983968,
    "first_name": "Abhik",
    "last_name": "Das",
    "email": ".Cle@rousmorepatted.qux",
    "salesforce_id": "003U000000i2YEkIAM",
    "last_activity_date": "2015-12-11T10:27:34.930Z"
  }
]
```
