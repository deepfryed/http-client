require 'webrick'
require 'stringio'
require 'socket'
require 'uri'

class TestServer
  attr_reader :port

  def initialize app
    @app      = app
    @port     = find_port
  end

  def run path = '/'
    logfile   = StringIO.new
    logger    = WEBrick::Log.new logfile
    accesslog = [[logfile, WEBrick::AccessLog::COMBINED_LOG_FORMAT]]

    @server = WEBrick::HTTPServer.new Port: @port, Logger: logger, AccessLog: accesslog
    @server.mount_proc(path) do |req, res|
      code, headers, body = @app.call(req)
      res.status = code
      headers.each do |k, v|
        res[k] = v
      end
      res.body = [body].flatten.join
    end

    Thread.abort_on_exception = true
    @thread = Thread.new {@server.start}
  end

  def stop
    @thread && @thread.kill
  end

  def root
    URI.parse("http://127.0.0.1:#{port}/")
  end

  private
    def find_port
      @tcp = TCPServer.new('127.0.0.1', 0) rescue nil
      @tcp or raise RuntimeError 'Unable to find a local TCP port to bind.'
      port = @tcp.addr[1]
      @tcp.close
      port
    end
end
