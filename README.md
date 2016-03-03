# Epiquery Client

A promise based [epiquery](https://github.com/glg/epiquery) client based on [bluebird](https://github.com/petkaantonov/bluebird/) and [request.js](https://github.com/request/request) that sets everything up for you the way you'd expect and provides some handy conveniences. It uses GLG's starphleet ENV conventions for configuring the server credentials by default, so you probably don't need to do anything else. In addition the epiquery client provides:

 * integrated [debug](https://github.com/visionmedia/debug) logging
 * a simple command line version
 * proxy service middleware layer
 * automatic retry, with progressive back off
 * configurable, increased request timeout
 
 To install, simply use the npm package manager
 
 ```shell
 npm install --save glg/glg-epiquery
 ```

## Making Requests

Typically you will simply use the `epiquery()` method to POST a template and optional payload to the server. There are also two convenience methods, `epiquery.get()` and `epiquery.post()` if you prefer. Each of these takes a template path relative to the epiquery server and an optional JSON object as its second parameter. In the case of `get()` the object is interpreted as a list of query string name/value pairs, rather than JSON payload.

### Typical usage (CoffeeScript)

```coffee-script
epiquery = require 'glg-epiquery'

epiquery '/glgCurrentUser/getUserByEmail.mustache',
  email: 'dfields@glgroup.com'
.then (users) ->
  console.log "Hi there, #{users[0]}.firstName"
```

### Typical usage (JavaScript)

```javascript
var epiquery = require('glg-epiquery');

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
epiquery = require 'glg-epiquery',
  server: "http://localhost:8088"
  timeout: 30
```

### Setting options (JavaScript)

```javascript
var epiquery = require('glg-epiquery', {
  server: "http://localhost:8088",
  timeout: 30
});
```

The `get()` and `post()` methods also accept an options hash as the last argument, allowing you to override options on a per request basis.

### Available configuration options

| option   | description     | env variable | default value                 |
|----------|-----------------|--------------|-------------------------------|
| server   | server url      | `EPIQUERY_SERVER`  | `http://localhost:7070` |
| username | server username | `EPIQUERY_USER`    |  none                   |
| password | server password | `EPIQUERY_PASSWORD`|  none                   |
| retries  | number of times to retry | `EPIQUERY_RETRIES` | 5 |
| backoff  | progressive delay between retries, in seconds | `EPIQUERY_BACKOFF` | 5|
| timeout  | request timeout, in seconds | `EPIQUERY_TIMEOUT` | 5 minutes |

## Proxy service middleware

A middleware service based on [express-request-proxy](https://github.com/4front/express-request-proxy) is provided that makes it to proxy calls from an express server. This makes it simple for your client side apps to talk to epiquery via your service without worrying about passing the configuration or authentication information from server to client. Simply mount the middleware on a local route, and you are good to go with a single line of code. You can pass in configuration options as an optional argument to the `proxy()` call if you need to change anything. There's an [example proxy server](bin/proxy.coffee) in the bin folder.

### Setting up an epiquery proxy (CoffeeScript)

```coffee-script
epiquery = require 'glg-epiquery'
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

## Epiquery from the command line

A simple command line version, simply called `epiquery` is provided. It takes a single argument, the template path. Might expand this functionality if it proves useful. There's also a command line version of the `proxy` server functionality.

## Integrated debugging

This library uses the [debug](https://github.com/visionmedia/debug) library to give you some useful debugging feedback, such as tracking request and responses and sampling the return response. To make anything show up you'll need to turn on the `epiquery` debugging via the `DEBUG` ENV variable like this:

```shell
export DEBUG=epiquery
```
