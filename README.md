# HTTP Client

A simple Net::HTTP wrapper with multi-part and cookie-jar support.

## Install

```
gem install http-client
```

## Example

```ruby
require 'http-client'
res = HTTP::Client::Request.new(:get, "http://a.b/", max_redirects: 2).execute

# save a few keystrokes.
res = HTTP::Client.get("http://a.b/", max_redirects: 2)
res = HTTP::Client.put("http://a.b/", files: {pic: "kittens.jpg"}, query: {title: "the usual suspects"})
res = HTTP::Client.post("http://a.b/", auth: {username: "test", password: "test"}, headers: {'x-a' => 'b'})
res = HTTP::Client.delete("http://a.b/", auth: {username: "test", password: "test"});
```

## API

```
HTTP::Client
    .get(uri, arguments = {})
    .put(uri, arguments = {})
    .post(uri, arguments = {})
    .head(uri, arguments = {})
    .trace(uri, arguments = {})
    .delete(uri, arguments = {})
    .options(uri, arguments = {})

HTTP::Client::Request
    .new(verb, uri, arguments = {})
    #execute

HTTP::Client::Response
    .new(net_http_response, last_effective_uri)
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

| Name | Type | Description | Default |
|------|------|-------------|---------|
| headers | Hash | Net::HTTP headers, in key-value pairs. | nil |
| query | Hash | Net::HTTP query-string in key-value pairs. | nil |
| files | Hash | Multi-part file uploads, in key-value pairs of {name => path_to_file} or {name => File} | nil |
| body | String | Request body. | nil |
| auth | Hash | Basic-Auth hash. {username: "...", password: "..."} | nil |
| timeout | Integer | Fixed timeout for connection, read and ssl handshake in seconds. | Net::HTTP default |
| open_timeout | Integer | Connection timeout in seconds. | Net::HTTP default |
| read_timeout | Integer | Read timeout in seconds. | Net::HTTP default |
| ssl_timeout | Integer | SSL handshake timeout in seconds. | Net::HTTP default |
| max_redirects | Integer | Maximum redirects follow. | 0 |
| ssl_verify | Integer | OpenSSL verification. HTTP::Client::SSL_VERIFY_PEER or HTTP::Client::SSL_VERIFY_NONE | SSL_VERIFY_PEER |
| jar | HTTP::CookieJar | Optional cookie jar to use. Relies on HTTP::CookieJar from http-cookie gem. | HTTP::CookieJar.new |

## Default behaviour

### SSL

* By default peer verification is done. You can turn this off by passing `ssl_verfy: HTTP::Client::SSL_VERIFY_NONE` option.

### Redirects

* By default the client does not follow redirects. You can enable this with a non-zero `max_redirects` option.
* 301, 302 and 303 redirects are always followed with a GET method.
* 307 and 308 redirects preserve original request method & body.

## License

MIT
