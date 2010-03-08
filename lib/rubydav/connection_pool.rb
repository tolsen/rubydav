require 'net/http'
require 'net/https'

module RubyDav

  class ConnectionPool

    unless defined? MAX_ATTEMPTS
      MAX_ATTEMPTS = 5 
      ROOT_CA = '/etc/ssl/certs'
    end

    attr_accessor :ssl_verify_mode

    # options: ssl_verify_mode
    def initialize opts = {}
      @requests = {}
      @ssl_verify_mode = opts[:ssl_verify_mode]
    end

    def request uri, request
      attempts = 0
      begin
        attempts += 1
        return self[uri].request(request)
      rescue IOError, Errno::ECONNRESET
        delete uri
        retry unless attempts >= MAX_ATTEMPTS
        raise
      end
    end
        
    private
        
    def [] uri
      anarchy_in_the_uri = self.class.uri_revolt uri
      unless @requests.include? anarchy_in_the_uri
        @requests[anarchy_in_the_uri] = http = Net::HTTP.new(uri.host, uri.port)

        if uri.scheme == "https"
          http.use_ssl = true

          if @ssl_verify_mode.nil?
            
            if File.directory? ROOT_CA
              http.ca_path = ROOT_CA
              http.verify_mode = OpenSSL::SSL::VERIFY_PEER
              http.verify_depth = 5
            end

          else
            http.verify_mode = @ssl_verify_mode
          end
          
        end

      end
      return @requests[anarchy_in_the_uri] 
    end

    def delete uri
      @requests.delete self.class.uri_revolt(uri)
    end

    class << self
      # gets rid of path (hierarchy) in uri, returning string
      def uri_revolt uri
        /^https?:\/\/[^\/]+/.match(uri.to_s)[0]
      end
    end

  end
end

    
