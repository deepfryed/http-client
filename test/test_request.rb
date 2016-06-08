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

  # TODO: mock http endpoint
  it 'executes a request and returns reponse' do
    assert HTTP::Client.get("http://www.google.com")
  end

  it 'raises timeout errors' do
    assert_raises(Net::OpenTimeout) {HTTP::Client.get("http://dingus.in:1000/", timeout: 0.2)}
  end
end
