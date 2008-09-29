require 'net/http'

module RubyDav

  class ConnectionPool

    MAX_ATTEMPTS = 5 unless defined? MAX_ATTEMPTS
    
    def initialize
      @requests = {}
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
      return @requests[anarchy_in_the_uri] if @requests.include? anarchy_in_the_uri
      return(@requests[anarchy_in_the_uri] = Net::HTTP.start(uri.host, uri.port))
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

    
