# HTTP Client

A simple Net::HTTP wrapper with multi-part and cookie-jar support.

## Install

```
gem install http-client
```

## Example

```ruby
require 'http-client'
res = HTTP::Client::Request.new(:get, "http://www.example.org", max_redirects: 2).execute

# save a few keystrokes.
res = HTTP::Client.get("http://www.example.org/", max_redirects: 2)
res = HTTP::Client.post(
  "http://www.example.org/",
  files: {pic: "kittens.jpg"},
  query: {title: "the usual suspects"}
)
```

## API

```
HTTP::Client::Request
    .new(verb, uri, arguments = {})
    #execute

HTTP::Client::Response
    .new net_http_response, last_effective_uri
    #code
    #body
    #headers
    #last_effective_uri
```

### Request parameters

#### Required

| Name | Type | Description |
|------|------|-------------|
| verb | Symbol | HTTP verb, one of :get, :head, :put, :post, :delete, :options, :trace. |
| uri | String or URI | Remote URI |

#### Optional arguments hash

| Name | Type | Description |
|------|------|-------------|
| headers | Hash | Net::HTTP headers, in key-value pairs. |
| query | Hash | Net::HTTP query-string in key-value pairs. |
| files | Hash | Multi-part file uploads, in key-value pairs of {name => path_to_file} or {name => File} |
| body | String | Request body. |
| auth | Hash | Basic-Auth hash. {username: "...", password: "..."} |
| timeout | Integer | Fixed timeout for connection, read and ssl handshake in seconds. |
| open_timeout | Integer | Connection timeout in seconds. |
| read_timeout | Integer | Read timeout in seconds. |
| ssl_timeout | Integer | SSL handshake timeout in seconds. |
| max_redirects | Integer | Max redirect follow, default: 0 |
| ssl_verify | Integer | OpenSSL verification, HTTP::Client::SSL_VERIFY_PEER or HTTP::Client::SSL_VERIFY_NONE, defaults to SSL_VERIFY_PEER. |
| jar | HTTP::CookieJar | Optional cookie jar to use. Relies on HTTP::CookieJar from http-cookie gem. |

## TODO

Extensive testing :/

## License

MIT
