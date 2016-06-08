require 'securerandom'
require 'net/http'
require 'openssl'
require 'uri'
require 'mime/types'
require 'http-cookie'

module HTTP
  module Client
    VERSION = '0.1.0'

    GET                     = Net::HTTP::Get
    HEAD                    = Net::HTTP::Head
    PUT                     = Net::HTTP::Put
    POST                    = Net::HTTP::Post
    DELETE                  = Net::HTTP::Delete
    OPTIONS                 = Net::HTTP::Options
    TRACE                   = Net::HTTP::Trace
    VALID_VERBS             = [GET, HEAD, PUT, POST, DELETE, OPTIONS, TRACE]

    SSL_VERIFY_NONE         = OpenSSL::SSL::VERIFY_NONE
    SSL_VERIFY_PEER         = OpenSSL::SSL::VERIFY_PEER
    VALID_SSL_VERIFICATIONS = [SSL_VERIFY_NONE, SSL_VERIFY_PEER]

    DEFAULT_HEADERS         = {'User-Agent' => 'HTTP Client API/1.0'}

    class Request
      attr_reader :uri

      VALID_PARAMETERS = %w(headers files query body auth timeout open_timeout ssl_timeout read_timeout max_redirects ssl_verify jar)

      # Create a new HTTP Client Request.
      #
      # @param verb          [Symbol]          HTTP verb, one of :get, :head, :put, :post, :delete, :options, :trace.
      # @param uri           [String]          Remote URI
      # @param headers       [Hash]            Net::HTTP headers, in key-value pairs.
      # @param query         [Hash]            Net::HTTP query-string in key-value pairs.
      # @param files         [Hash]            Multi-part file uploads, in key-value pairs of {name => path_to_file} or {name => File}
      # @param body          [String]          Request body.
      # @param auth          [Hash]            Basic-Auth hash. {username: "...", password: "..."}
      # @param timeout       [Integer]         Fixed timeout for connection, read and ssl handshake in seconds.
      # @param open_timeout  [Integer]         Connection timeout in seconds.
      # @param read_timeout  [Integer]         Read timeout in seconds.
      # @param ssl_timeout   [Integer]         SSL handshake timeout in seconds.
      # @param max_redirects [Integer]         Max redirect follow, default: 0
      # @param ssl_verify    [Integer]         OpenSSL verification, HTTP::Client::SSL_VERIFY_PEER or HTTP::Client::SSL_VERIFY_NONE, defaults to SSL_VERIFY_PEER.
      # @param jar           [HTTP::CookieJar] Optional cookie jar to use. Relies on HTTP::CookieJar from http-cookie gem.
      #
      # @return [HTTP::Client::Request]
      #
      def initialize verb, uri, args = {}
        args.each do |k, v|
          raise ArgumentError, "unknown argument #{k}" unless VALID_PARAMETERS.include?(k.to_s)
        end

        parse_uri! uri
        setup_request_delegate! verb, args

        if body = args[:body]
          raise ArgumentError, "#{verb} cannot have body" unless klass.const_get(:REQUEST_HAS_BODY)
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

        @redirects    = args.fetch(:max_redirects, 0)
        @ssl_verify   = args.fetch(:ssl_verify, SSL_VERIFY_PEER)
        @jar          = args.fetch(:jar, HTTP::CookieJar.new)
      end

      # Executes a request.
      #
      # @return [HTTP::Client::Response]
      #
      def execute
        @last_effective_uri = uri

        cookie = HTTP::Cookie.cookie_value(@jar.cookies(uri))
        if cookie && !cookie.empty?
          @delegate.add_field('Cookie', cookie)
        end

        response = request!(uri, @delegate)
        @jar.parse(response['set-cookie'].to_s, uri)

        while @redirects > 0 && [301, 302, 307].include?(response.code.to_i)
          @redirects -= 1
          redirect    = redirect_to(response['location'])

          cookie = HTTP::Cookie.cookie_value(@jar.cookies(@last_effective_uri))
          if cookie && !cookie.empty?
            redirect.add_field('Cookie', cookie)
          end

          response = request!(@last_effective_uri, redirect)
          @jar.parse(response['set-cookie'].to_s, @last_effective_uri)
        end

        Response.new(response, @last_effective_uri)
      end

      private
        def parse_uri! uri
          @uri = URI.parse(uri)
          case @uri
            when URI::HTTP, URI::HTTPS
              # ok
            else
              raise ArgumentError, "Invalid URI #{uri}"
          end
        end

        def setup_request_delegate! verb, args
          klass    = find_delegate_class(verb)
          @headers = DEFAULT_HEADERS.merge(args.fetch(:headers, {}))

          files    = args[:files]
          qs       = args[:query]

          if files
            raise ArgumentError, "#{verb} cannot have body" unless klass.const_get(:REQUEST_HAS_BODY)
            multipart              = Multipart.new(files, qs)
            @delegate              = klass.new(@uri.request_uri, headers_for(@uri))
            @delegate.content_type = multipart.content_type
            @delegate.body         = multipart.body
          elsif qs
            if klass.const_get(:REQUEST_HAS_BODY)
              @delegate = klass.new(@uri.request_uri, headers_for(@uri))
              @delegate.set_form_data(qs)
            else
              @uri.query = URI.encode_www_form(qs)
              @delegate = klass.new(@uri.request_uri, headers_for(@uri))
            end
          else
            @delegate = klass.new(@uri.request_uri, headers_for(@uri))
          end
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

        def redirect_to uri
          @last_effective_uri = URI.parse(uri)
          GET.new(@last_effective_uri.request_uri, headers_for(@last_effective_uri))
        end

        def headers_for uri
          @headers
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
      attr_reader :last_effective_uri

      def initialize response, last_effective_uri
        @response           = response
        @last_effective_uri = last_effective_uri
      end

      def code
        @response.code.to_i
      end

      def headers
        @headers ||= @response.each_header.entries
      end

      def body
        @response.body
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
      # @return [HTTP::Client::Response]
      #
      def get     *args; Request.new(GET, *args).execute; end

      # Creates a PUT request and executes it, returning the response.
      # @see HTTP::Client::Request#initialize
      #
      # @return [HTTP::Client::Response]
      #
      def put     *args; Request.new(PUT, *args).execute; end

      # Creates a POST request and executes it, returning the response.
      # @see HTTP::Client::Request#initialize
      #
      # @return [HTTP::Client::Response]
      #
      def post    *args; Request.new(POST, *args).execute; end

      # Creates a DELETE request and executes it, returning the response.
      # @see HTTP::Client::Request#initialize
      #
      # @return [HTTP::Client::Response]
      #
      def delete  *args; Request.new(DELETE, *args).execute; end

      # Creates a OPTIONS request and executes it, returning the response.
      # @see HTTP::Client::Request#initialize
      #
      # @return [HTTP::Client::Response]
      #
      def options *args; Request.new(OPTIONS, *args).execute; end

      # Creates a TRACE request and executes it, returning the response.
      # @see HTTP::Client::Request#initialize
      #
      # @return [HTTP::Client::Response]
      #
      def trace   *args; Request.new(TRACE, *args).execute; end
    end
  end # Client
end # HTTP
