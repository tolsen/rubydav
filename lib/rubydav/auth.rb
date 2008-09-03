# auth.rb contains DigestAuth class which adds the basic or digest authentication on the request object.

require 'net/http'
require 'base64'
require 'digest/md5'

require 'rubygems'
require 'httpauth/digest'

module RubyDav

  srand ( Time.now.to_i * $$ ) % 2**30 # don't rollover into a bignum

  class Auth
    attr_reader :realm
    attr_accessor :username, :password

    class << self
      # create a new Auth given the value of the
      # WWW-Authenticate header
      def construct www_authenticate
        case www_authenticate
        when /^Basic realm="(.*)"/
          return BasicAuth.new($1)
        when /^Digest\s+.*realm="([^"]*)"/
          return DigestAuth.new($1, www_authenticate)
        else
          raise ArgumentError, "Invalid WWW-Authenticate header: #{www_authenticate}"
        end

      end
    end


    def initialize realm
      @realm = realm
    end

    # returns :basic or :digest
    def scheme
      return nil if self.instance_of? Auth
      return /([A-Z][a-z]+)Auth$/.match(self.class.name)[1].downcase.to_sym
    end
  end
  
  
  class BasicAuth < Auth
    attr_writer :creds

    def authorization *args
      if @creds.nil?
        raise "(username & password) or creds need to be set before calling BasicAuth#authorization()" unless @username && @password
        @creds = Base64.encode64("#{@username}:#{@password}").gsub("\n", '')
      end
      return "Basic #{@creds}"
    end
    
  end
  

  class DigestAuth < Auth
    attr_writer :h_a1
    attr_reader :domain, :stale

    def initialize realm_or_creds, www_authenticate = nil
      if www_authenticate.nil?
        @credentials = realm_or_creds
        super @credentials.h[:realm]
      else
        super realm_or_creds
        @challenge = HTTPAuth::Digest::Challenge.from_header www_authenticate
        @domain = @challenge.h[:domain]
        @stale = @challenge.h[:stale]
        @salt = [[rand(2**30)].pack('N')].pack('m').chomp
      end
    end

    def stale?() self.stale; end

    def authorization method, uri
      raise "username must be set before calling DigestAuth#authorization()" if @username.nil?
      if @h_a1.nil?
        raise "Either h_a1 or password must be set before calling DigestAuth#authorization()" if @password.nil?
        @h_a1 = HTTPAuth::Digest::Utils.htdigest @username, @realm, @password
      end

      if @credentials.nil?
        @credentials =
          HTTPAuth::Digest::Credentials.from_challenge(@challenge,
                                                       :uri => uri,
                                                       :username => @username,
                                                       :digest => @h_a1,
                                                       :method => method,
                                                       :salt => @salt)
      else
        @credentials.update_from_challenge!( :uri => uri,
                                             :method => method,
                                             :username => @username,
                                             :digest => @h_a1 )

      end

      hdr = @credentials.to_header
      @credentials.h[:nc] ||= 0
      @credentials.h[:nc] += 1
      return hdr
    end

    # validates rspauth part of the Authentication-Info header
    # and reads in the nextnonce
    # returns true if rspauth is valid, false otherwise
    def validate_auth_info auth_info
      @auth_info = HTTPAuth::Digest::AuthenticationInfo.from_header auth_info
      valid_rspauth = @auth_info.validate(:digest => @h_a1,
                                          :nonce => @credentials.h[:nonce],
                                          :uri => @credentials.h[:uri])
      
      if @auth_info.h[:nextnonce] && @auth_info.h[:nextnonce] != @credentials.h[:nonce]
        @credentials.h[:nonce] = @auth_info.h[:nextnonce]
        @credentials.h[:nc] = 1
      end
      
      return valid_rspauth
    end

    def dump_sans_creds filename
      @credentials.dump_sans_creds filename
    end

    def self.load filename
      creds = HTTPAuth::Digest::Credentials.load filename
      new creds
    end

  end

    
    
  
  
end
