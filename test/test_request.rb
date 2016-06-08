require_relative 'helper'

describe 'HTTP Client Request' do
  it 'should reject invalid arguments' do
    assert_raises(ArgumentError, "invalid verb")        {HTTP::Client::Request.new(:foo)}
    assert_raises(URI::InvalidURIError, "invalid uri")  {HTTP::Client::Request.new(:get, "http://")}
    assert_raises(ArgumentError, "invalid argument")    {HTTP::Client::Request.new(:get, "http://example.org/", foo: 1)}
  end

  it 'validates body based on request verb' do
    assert_raises(ArgumentError, "get cannot have body") {HTTP::Client::Request.new(:get, "http://a.c", files: {test: __FILE__})}
  end

  it 'allows creation of valid request object' do
    assert HTTP::Client::Request.new(
      :post,
      "http://example.org/",
      query:         {title: "test"},
      files:         {test1: __FILE__, test2: __FILE__},
      max_redirects: 2,
      timeout:       10,
      ssl_verify:    HTTP::Client::SSL_VERIFY_NONE,
      body:          'Hello world!'
    )
  end

  it 'executes a request and returns reponse' do
    app    = proc {|req| [200, {}, "Hello World!"]}
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
    assert_raises(Net::ReadTimeout) {HTTP::Client.get(server.root, timeout: 0.2)}
  end

  it 'handles redirects' do
    app = proc do |req|
      case req.path
        when '/redirect2'
          [200, {}, "Hello World!"]
        when '/redirect1'
          [302, {'Location' => '/redirect2'}, "Moved!"]
        when '/'
          [302, {'Location' => '/redirect1'}, "Moved!"]
      end
    end
    server = TestServer.new(app)
    server.run

    response = HTTP::Client.get(server.root)
    assert_equal 302, response.code
    assert_equal %Q{#{server.root + "/redirect1"}}, response.headers['location']

    response = HTTP::Client.get(server.root, max_redirects: 1)
    assert_equal 302, response.code
    assert_equal %Q{#{server.root + "/redirect1"}}, response.last_effective_uri.to_s
    assert_equal %Q{#{server.root + "/redirect2"}}, response.headers['location']

    response = HTTP::Client.get(server.root, max_redirects: 2)
    assert_equal 200, response.code
    assert_equal %Q{#{server.root + "/redirect2"}}, response.last_effective_uri.to_s
  end

  it 'posts url encoded form' do
    qs = {}
    app = proc do |req|
      qs = req.query
      [200, {}, "OK!"]
    end
    server = TestServer.new(app)
    server.run

    response = HTTP::Client.post(server.root, query: {test1: "test2"})
    server.stop
    assert_equal 200,     response.code
    assert_equal "test2", qs["test1"]
  end

  it 'posts multi-part encoded data' do
    qs = {}
    app = proc do |req|
      qs = req.query
      [200, {}, "OK!"]
    end
    server = TestServer.new(app)
    server.run

    response = HTTP::Client.post(server.root, files: {this: __FILE__}, query: {test1: "test2"})
    server.stop

    assert_equal 200,     response.code
    assert_equal "test2", qs["test1"]

    data = IO.read(__FILE__)
    assert_equal data, qs["this"]
    assert_equal File.basename(__FILE__), qs["this"].filename # people should stop overloading / extending String!
  end
end
