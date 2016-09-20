require 'securerandom'
require 'net/http'
require 'openssl'
require 'uri'
require 'mime/types'
require 'http-cookie'
require 'stringio'
require 'zlib'

module HTTP
  module Client
    VERSION = '0.2.2'

    GET                     = Net::HTTP::Get
    HEAD                    = Net::HTTP::Head
    PUT                     = Net::HTTP::Put
    POST                    = Net::HTTP::Post
    DELETE                  = Net::HTTP::Delete
    OPTIONS                 = Net::HTTP::Options
    TRACE                   = Net::HTTP::Trace

    SSL_VERIFY_NONE         = OpenSSL::SSL::VERIFY_NONE
    SSL_VERIFY_PEER         = OpenSSL::SSL::VERIFY_PEER

    class Error < StandardError;
    end

    class ArgumentError < Error;
    end

    class Request
      VALID_PARAMETERS        = %w(headers files query body auth timeout open_timeout ssl_timeout read_timeout max_redirects ssl_verify jar)
      DEFAULT_HEADERS         = {'User-Agent' => 'HTTP Client API/1.0'}

      REDIRECT_WITH_GET       = [301, 302, 303]
      REDIRECT_WITH_ORIGINAL  = [307, 308]

      VALID_VERBS             = [GET, HEAD, PUT, POST, DELETE, OPTIONS, TRACE]
      VALID_SSL_VERIFICATIONS = [SSL_VERIFY_NONE, SSL_VERIFY_PEER]
      VALID_REDIRECT_CODES    = REDIRECT_WITH_GET + REDIRECT_WITH_ORIGINAL

      # Create a new HTTP Client Request.
      #
      # @param  [Symbol]               verb            HTTP verb, one of :get, :head, :put, :post, :delete, :options, :trace.
      # @param  [String or URI]        uri             Remote URI.
      # @param  [Hash]                 args            Options, see below.
      # @option args [Hash]            headers         Net::HTTP headers, in key-value pairs.
      # @option args [Hash]            query           Net::HTTP query-string in key-value pairs.
      # @option args [Hash]            files           Multi-part file uploads, in key-value pairs of name & path or name & File object.
      # @option args [String]          body            Request body.
      # @option args [Hash]            auth            Basic-Auth hash. Requires :username and :password.
      # @option args [Integer]         timeout         Fixed timeout for connection, read and ssl handshake in seconds.
      # @option args [Integer]         open_timeout    Connection timeout in seconds.
      # @option args [Integer]         read_timeout    Read timeout in seconds.
      # @option args [Integer]         ssl_timeout     SSL handshake timeout in seconds.
      # @option args [Integer]         max_redirects   Max redirect follow, default: 0
      # @option args [Integer]         ssl_verify      OpenSSL verification, SSL_VERIFY_PEER or SSL_VERIFY_NONE, defaults to SSL_VERIFY_PEER.
      # @option args [HTTP::CookieJar] jar             Optional cookie jar to use. Relies on HTTP::CookieJar from http-cookie gem.
      #
      # @return [HTTP::Client::Request]
      #
      # @example Retrieve a page using GET.
      #   request  = HTTP::Client::Request.new(:get, "http://www.example.org/", query: {q: "search something"})
      #   response = request.execute
      #
      # @example Handle redirects.
      #   request  = HTTP::Client::Request.new(:get, "http://www.example.org/", max_redirects: 3)
      #   response = request.execute
      #
      # @example Perform request and return result in one go.
      #   response = HTTP::Client.get("http://www.example.org/", max_redirects: 3)
      #
      # @example Upload a few files in a POST request.
      #   request  = HTTP::Client::Request.new(:post, "http://www.example.org/", files: {"cats" => "cats.jpg", "dogs" => "dogs.jpg"}, query: {title: "cute pics"})
      #   response = request.execute
      #
      # @example Pass in an external cookie jar.
      #   jar  = HTTP::CookieJar.new
      #   jar.load("mycookies.cky")
      #   response = HTTP::Client.get("http://www.example.org/", jar: jar)
      #
      def initialize verb, uri, args = {}
        args.each do |k, v|
          raise ArgumentError, "unknown argument #{k}" unless VALID_PARAMETERS.include?(k.to_s)
        end

        uri       = parse_uri!(uri)
        @delegate = create_request_delegate(verb, uri, args)

        if body = args[:body]
          raise ArgumentError, "#{verb} cannot have body" unless @delegate.class.const_get(:REQUEST_HAS_BODY)
          @delegate.body = body
        end

        if auth = args[:auth]
          @delegate.basic_auth(auth.fetch(:username), auth.fetch(:password))
        end

        # generic timeout
        if timeout = args[:timeout]
          @open_timeout = timeout
          @ssl_timeout  = timeout
          @read_timeout = timeout
        end

        # overrides
        @open_timeout = args[:open_timeout] if args[:open_timeout]
        @ssl_timeout  = args[:ssl_timeout]  if args[:ssl_timeout]
        @read_timeout = args[:read_timeout] if args[:read_timeout]

        @max_redirects = args.fetch(:max_redirects, 0)
        @ssl_verify    = args.fetch(:ssl_verify, SSL_VERIFY_PEER)
        @jar           = args.fetch(:jar, HTTP::CookieJar.new)
      end

      # Executes a request.
      #
      # @return [HTTP::Client::Response]
      #
      def execute
        last_effective_uri = uri

        cookie = HTTP::Cookie.cookie_value(@jar.cookies(uri))
        if cookie && !cookie.empty?
          @delegate.add_field('Cookie', cookie)
        end

        response = request!(uri, @delegate)
        @jar.parse(response['set-cookie'].to_s, uri)

        redirects = 0
        while redirects < @max_redirects && VALID_REDIRECT_CODES.include?(response.code.to_i)
          redirects         += 1
          last_effective_uri = parse_uri! response['location']
          redirect_delegate  = redirect_to(last_effective_uri, response.code.to_i)

          cookie = HTTP::Cookie.cookie_value(@jar.cookies(last_effective_uri))
          if cookie && !cookie.empty?
            redirect_delegate.add_field('Cookie', cookie)
          end

          response = request!(last_effective_uri, redirect_delegate)
          @jar.parse(response['set-cookie'].to_s, last_effective_uri)
        end

        Response.new(response, last_effective_uri)
      end

      private
        def uri
          @delegate.uri
        end

        def parse_uri! uri
          uri = uri.kind_of?(URI) ? uri : URI.parse(uri)
          case uri
            when URI::HTTP, URI::HTTPS
              raise ArgumentError, "Invalid URI #{uri}" if uri.host.nil?
              uri
            when URI::Generic
              if @delegate && @delegate.uri
                @delegate.uri.dup.tap {|s| s += uri }
              else
                raise ArgumentError, "Invalid URI #{uri}"
              end
            else
              raise ArgumentError, "Invalid URI #{uri}"
          end
        rescue URI::InvalidURIError => e
          raise ArgumentError, "Invalid URI #{uri}"
        end

        def create_request_delegate verb, uri, args
          klass   = find_delegate_class(verb)
          headers = DEFAULT_HEADERS.merge(args.fetch(:headers, {}))

          files    = args[:files]
          qs       = args[:query]
          uri      = uri.dup
          delegate = nil

          if files
            raise ArgumentError, "#{verb} cannot have body" unless klass.const_get(:REQUEST_HAS_BODY)
            multipart             = Multipart.new(files, qs)
            delegate              = klass.new(uri, headers)
            delegate.content_type = multipart.content_type
            delegate.body         = multipart.body
          elsif qs
            if klass.const_get(:REQUEST_HAS_BODY)
              delegate = klass.new(uri, headers)
              delegate.set_form_data(qs)
            else
              uri.query = URI.encode_www_form(qs)
              delegate  = klass.new(uri, headers)
            end
          else
            delegate = klass.new(uri, headers)
          end

          delegate
        end

        def request! uri, delegate
          http = Net::HTTP.new(uri.host, uri.port)
          if uri.scheme == 'https'
            http.use_ssl     = true
            http.verify_mode = @ssl_verify
          end

          http.open_timeout = @open_timeout if @open_timeout
          http.read_timeout = @read_timeout if @read_timeout
          http.ssl_timeout  = @ssl_timeout  if @ssl_timeout

          response = http.request(delegate)
          http.finish if http.started?
          response
        end

        def redirect_to uri, code
          # NOTE request-uri with query string is not preserved.
          case code
            when *REDIRECT_WITH_GET
              GET.new(uri, {}).tap do |r|
                @delegate.each_header do |field, value|
                  next if field.downcase == 'host'
                  r[field] = value
                end
              end
            when *REDIRECT_WITH_ORIGINAL
              @delegate.class.new(uri, {}).tap do |r|
                @delegate.each_header do |field, value|
                  next if field.downcase == 'host'
                  r[field] = value
                end

                r.body = @delegate.body
              end
            else
              raise Error, "response #{code} should not result in redirection."
          end
        end

        def find_delegate_class verb
          if VALID_VERBS.include?(verb)
            verb
          else
            find_verb_class(verb.to_s)
          end
        end

        def find_verb_class string
          case string
            when /^get$/i     then GET
            when /^head$/i    then HEAD
            when /^put$/i     then PUT
            when /^post$/i    then POST
            when /^delete$/i  then DELETE
            else
              raise ArgumentError, "Invalid verb #{string}"
          end
        end
    end # Request

    class Response
      attr_reader :last_effective_uri, :response

      def initialize response, last_effective_uri
        @response           = response
        @last_effective_uri = last_effective_uri
      end

      def code
        response.code.to_i
      end

      def headers
        @headers ||= Hash[response.each_header.entries]
      end

      def body
        case headers['content-encoding'].to_s.downcase
          when 'gzip'
            gz = Zlib::GzipReader.new(StringIO.new(response.body))
            begin
              gz.read
            ensure
              gz.close
            end
          when 'deflate'
            Zlib.inflate(response.body)
          else
            response.body
        end
      end

      def inspect
        "#<#{self.class} @code=#{code} @last_effective_uri=#{last_effective_uri}>"
      end
    end # Response

    class Multipart
      attr_reader :boundary

      EOL               = "\r\n"
      DEFAULT_MIME_TYPE = 'application/octet-stream'

      def initialize files, query = {}
        @files    = files
        @query    = query
        @boundary = generate_boundary
      end

      def content_type
        "multipart/form-data; boundary=#{boundary}"
      end

      def body
        body      = ''.encode('ASCII-8BIT')
        separator = "--#{boundary}"

        @query.each do |key, value|
          body << separator << EOL
          body << %Q{Content-Disposition: form-data; name="#{key}"} << EOL
          body << EOL
          body << value
          body << EOL
        end

        @files.each do |name, handle|
          if handle.respond_to?(:read)
            path = handle.path
            data = io.read
          else
            path = handle
            data = IO.read(path)
          end

          filename = File.basename(path)
          mime     = mime_type(filename)

          body << separator << EOL
          body << %Q{Content-Disposition: form-data; name="#{name}"; filename="#{filename}"} << EOL
          body << %Q{Content-Type: #{mime}}              << EOL
          body << %Q{Content-Transfer-Encoding: binary}  << EOL
          body << %Q{Content-Length: #{data.bytesize}}   << EOL
          body << EOL
          body << data
          body << EOL
        end

        body << separator << "--" << EOL
        body
      end

      private
        def generate_boundary
          SecureRandom.random_bytes(16).unpack('H*').first
        end

        def mime_type filename
          MIME::Types.type_for(File.extname(filename)).first || DEFAULT_MIME_TYPE
        end
    end # Multipart

    # Helpers
    class << self
      # Creates a GET request and executes it, returning the response.
      # @see HTTP::Client::Request#initialize
      #
      # @param  [String or URI] uri   Remote URI.
      # @param  [Hash]          args  Options, see HTTP::Client::Request#initialize.
      # @return [HTTP::Client::Response]
      #
      def get uri, args = {}; Request.new(GET, uri, args).execute; end

      # Creates a PUT request and executes it, returning the response.
      # @see HTTP::Client::Request#initialize
      #
      # @param  [String or URI] uri   Remote URI.
      # @param  [Hash]          args  Options, see HTTP::Client::Request#initialize.
      # @return [HTTP::Client::Response]
      #
      def put uri, args = {}; Request.new(PUT, uri, args).execute; end

      # Creates a POST request and executes it, returning the response.
      # @see HTTP::Client::Request#initialize
      #
      # @param  [String or URI] uri   Remote URI.
      # @param  [Hash]          args  Options, see HTTP::Client::Request#initialize.
      # @return [HTTP::Client::Response]
      #
      def post  uri, args = {}; Request.new(POST, uri, args).execute; end

      # Creates a DELETE request and executes it, returning the response.
      # @see HTTP::Client::Request#initialize
      #
      # @param  [String or URI] uri   Remote URI.
      # @param  [Hash]          args  Options, see HTTP::Client::Request#initialize.
      # @return [HTTP::Client::Response]
      #
      def delete uri, args = {}; Request.new(DELETE, uri, args).execute; end

      # Creates a OPTIONS request and executes it, returning the response.
      # @see HTTP::Client::Request#initialize
      #
      # @param  [String or URI] uri   Remote URI.
      # @param  [Hash]          args  Options, see HTTP::Client::Request#initialize.
      # @return [HTTP::Client::Response]
      #
      def options uri, args = {}; Request.new(OPTIONS, uri, args).execute; end

      # Creates a TRACE request and executes it, returning the response.
      # @see HTTP::Client::Request#initialize
      #
      # @param  [String or URI] uri   Remote URI.
      # @param  [Hash]          args  Options, see HTTP::Client::Request#initialize.
      # @return [HTTP::Client::Response]
      #
      def trace uri, args = {}; Request.new(TRACE, uri, args).execute; end
    end
  end # Client
end # HTTP
