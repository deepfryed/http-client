require 'zlib'
require 'stringio'
require_relative 'helper'

describe 'HTTP Client Request' do
  before do
    HTTP::Client.so_linger = true
  end

  it 'should reject invalid arguments' do
    assert_raises(HTTP::Client::Error::Argument, 'invalid verb') {HTTP::Client::Request.new(:foo, 'http://example.org/')}
    assert_raises(HTTP::Client::Error::URI, 'invalid uri') {HTTP::Client::Request.new(:get, 'http://')}
    assert_raises(HTTP::Client::Error::URI, 'invalid uri') {HTTP::Client::Request.new(:get, '/hello')}

    assert_raises(HTTP::Client::Error::Argument, 'invalid argument')  do
      HTTP::Client::Request.new(:get, 'http://example.org/', foo: 1)
    end
  end

  it 'validates body based on request verb' do
    assert_raises(HTTP::Client::Error::Argument, 'get cannot have body') do
      HTTP::Client::Request.new(:get, 'http://a.c', files: {test: __FILE__})
    end
  end

  it 'allows creation of valid request object' do
    assert HTTP::Client::Request.new(
      :post,
      'http://example.org/',
      query:         {title: 'test'},
      files:         {test1: __FILE__, test2: __FILE__},
      max_redirects: 2,
      timeout:       10,
      ssl_verify:    HTTP::Client::SSL_VERIFY_NONE,
      body:          'Hello world!'
    )
  end

  it 'executes a request and returns reponse' do
    app    = proc {|req| [200, {}, 'Hello World!']}
    server = TestServer.new(app)
    server.run

    response = HTTP::Client.get(server.root)
    server.stop
    assert response
    assert_kind_of Hash, response.headers
  end

  it 'raises timeout errors' do
    app    = proc {|req| sleep }
    server = TestServer.new(app)
    server.run
    assert_raises(HTTP::Client::Error::Timeout) {HTTP::Client.get(server.root, timeout: 0.2)}
  end

  it 'handles redirects' do
    cookie  = 'foo=bar; expires=Mon, 31-Dec-2038 23:59:59 GMT; path=/; domain=.127.0.0.1'

    [301, 302, 303, 307, 308]. each do |code|
      cookies = []
      methods = []
      headers = {}
      app     = proc do |req|
        cookies << req['cookie']
        case req.path
          when '/redirect2'
            req.each {|k,v| headers[k] = v}
            methods << req.request_method
            [200, {}, 'Hello World!']
          when '/redirect1'
            methods << req.request_method
            [code, {'Location' => '/redirect2'}, 'Moved!']
          when '/'
            [code, {'Location' => '/redirect1', 'Set-Cookie' => cookie}, 'Moved!']
        end
      end

      server = TestServer.new(app)
      server.run

      response = HTTP::Client.post(server.root)
      assert_equal code, response.code
      assert_equal %Q{#{server.root + '/redirect1'}}, response.headers['location']

      response = HTTP::Client.post(server.root, max_redirects: 1)
      assert_equal code, response.code
      assert_equal %Q{#{server.root + '/redirect1'}}, response.last_effective_uri.to_s
      assert_equal %Q{#{server.root + '/redirect2'}}, response.headers['location']

      response = HTTP::Client.post(server.root, headers: {'x-foo-1' => 'bar'}, max_redirects: 2)
      assert_equal 200, response.code
      assert_equal %Q{#{server.root + '/redirect2'}}, response.last_effective_uri.to_s

      server.stop
      cookies.compact!
      assert_equal 3, cookies.size
      assert_equal 1, cookies.uniq.size
      assert_equal 'foo=bar', cookies.first

      methods.compact!
      assert_equal 1, methods.uniq.size
      if [307, 308].include?(code)
        assert_equal 'POST', methods.first
      else
        assert_equal 'GET', methods.first
      end

      assert_equal 'bar',  headers['x-foo-1']
    end
  end

  it 'handles HTTP 1.1 redirects' do
    [307, 308].each do |code|
      bucket = []
      app    = proc do |req|
        case req.path
          when '/redirect'
            bucket = req.query
            [200, {}, 'Hello World!']
          when '/'
            [code, {'Location' => '/redirect'}, 'Moved!']
        end
      end

      server = TestServer.new(app)
      server.run

      response = HTTP::Client.post(server.root, query: {foo: 'bar'}, files: {baz: __FILE__}, max_redirects: 1)
      assert_equal 200, response.code
      assert_equal %Q{#{server.root + '/redirect'}}, response.last_effective_uri.to_s
      server.stop

      assert bucket['foo'], 'query 1 preserved'
      assert bucket['baz'], 'file upload preserved'
    end
  end

  it 'posts url encoded form' do
    qs = {}
    app = proc do |req|
      qs = req.query
      [200, {}, 'OK!']
    end
    server = TestServer.new(app)
    server.run

    response = HTTP::Client.post(server.root, query: {test1: 'test2'})
    server.stop
    assert_equal 200,     response.code
    assert_equal 'test2', qs['test1']
  end

  it 'posts multi-part encoded data' do
    qs = {}
    app = proc do |req|
      qs = req.query
      [200, {}, 'OK!']
    end
    server = TestServer.new(app)
    server.run

    response = HTTP::Client.post(server.root, files: {this: __FILE__}, query: {test1: 'test2'})
    server.stop

    assert_equal 200,     response.code
    assert_equal 'test2', qs['test1']

    data = IO.read(__FILE__)
    assert_equal data, qs['this']
    assert_equal File.basename(__FILE__), qs['this'].filename # people should stop overloading / extending String!
  end

  it 'handles gzip and deflate compression schemes.' do
    app = proc do |req|
      case req.path
        when '/gzip'
          [
            200,
            {'content-encoding' => 'gzip'},
            StringIO.new.tap {|io|
              gz = Zlib::GzipWriter.new(io)
              gz.write("Hello 1")
              gz.close
            }.string
          ]
        when '/deflate'
          [200, {'content-encoding' => 'deflate'}, Zlib.deflate("Hello 2")]
      end
    end

    server = TestServer.new(app)
    server.run

    response = HTTP::Client.get("#{server.root}/gzip", headers: {'accept-encoding' => 'gzip;deflate'})
    assert_equal 'Hello 1', response.body, 'gunzip ok'

    response = HTTP::Client.get("#{server.root}/deflate", headers: {'accept-encoding' => 'gzip;deflate'})
    assert_equal 'Hello 2', response.body, 'inflate ok'
    server.stop
  end
end
