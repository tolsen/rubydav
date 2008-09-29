# $Id$
# $URL$

require 'bsearch'
require 'uri'

module RubyDav


  # represents a set of protection spaces for a request object
  class AuthWorld

    def initialize
      @spaces = []
    end

    def get_auth url, client_opts
      l = @spaces.bsearch_lower_boundary { |x| x.prefix <=> url }

      # skip the one found if it's not the same authority
      l -= 1 unless l < @spaces.length && self.class.equal_authority?(url, @spaces[l].prefix)

      digest_auth = basic_auth = nil
      
      @spaces[0..l].reverse.each do |s|
        # if we're now looking at a non-matching authority, then we've passed
        # all matching authorities
        return nil unless self.class.equal_authority? url, s.prefix

        if self.class.prefix? s.prefix, url
          digest_auth = s.get_auth :digest, client_opts if digest_auth.nil?
          # prefer digest authentication
          return digest_auth if digest_auth && !client_opts[:force_basic_auth]
          
          basic_auth = s.get_auth :basic, client_opts if basic_auth.nil?
          return basic_auth if basic_auth && client_opts[:force_basic_auth]
        end
      end

      return basic_auth if basic_auth
      return nil
    end
    
    def add_auth auth, url, client_opts
      raise "malformed url: #{url}" unless
        url =~ /^https?:\/\/[^\/]/
        
      url = self.class.ensure_trailing_slash_if_no_hierarchy(url)
      self.send "add_auth_#{auth.scheme.to_s}".to_sym, auth, url, client_opts
    end

    private

    # url's without any path must end with trailing slash
    # e.g. http://example.com is not ok
    def add_auth_basic auth, url, client_opts
      l = @spaces.bsearch_lower_boundary { |x| x.prefix <=> url }
      space = nil

      if l < @spaces.length && self.class.prefix?(@spaces[l].prefix, url)
        space = @spaces[l]
      else
        prefix = url.sub /[^\/]+$/, '' # chop off until last slash
        
        space = AuthSpace.new prefix
        @spaces.insert l, space
      end
      space.update_auth auth, client_opts
    end

    # url's without any path must end with trailing slash
    # e.g. http://example.com is not ok
    def add_auth_digest auth, url, client_opts
      uri = URI.parse url

      abs_domains = if auth.domain.nil? || auth.domain.empty?
                      [ /^https?:\/\/[^\/]+\//.match(url)[0] ]
                    else
                      auth.domain.map do |d|
                        domain_uri = URI.parse d
                        d = URI.join(url, d).to_s if domain_uri.relative?
                        d
                      end
                    end

      abs_domains.each do |domain|
        l = @spaces.bsearch_lower_boundary { |x| x.prefix <=> domain }
        space = l < @spaces.length ? @spaces[l] : nil

        if space.nil? ||  space.prefix != domain
          space = AuthSpace.new domain
          @spaces.insert l, space
        end
        space.update_auth auth, client_opts
      end
    end
      

    class << self
      
      def prefix? url1, url2
        u1, u2 = url1, ensure_trailing_slash_if_no_hierarchy(url2)
        
        return false if u1.length > u2.length
        return true if u1 == u2

        # it is a prefix if u1 matches the beginning of u2 and
        # u1 ends with a slash or the character in u2 after
        # matching u1 is a slash
        return true if
          u2[0..(u1.length - 1)] == u1 &&
          (u1[-1].chr == '/' || u2[u1.length].chr == '/')

        return false
      end

      def ensure_trailing_slash_if_no_hierarchy url
        url.sub(/(https?:\/\/[^\/]+)$/, '\1/')
      end

      def equal_authority? url1, url2
        uri1, uri2 = URI.parse(url1), URI.parse(url2)
        uri1.scheme == uri2.scheme &&
          uri1.host == uri2.host &&
          uri1.port == uri2.port
      end
      
    end
    
  end
  
  
  # represents a protection space
  class AuthSpace

    include Comparable
    
    # URI prefix
    # Must be an absolute URI
    attr_reader :prefix

    def initialize prefix
      @prefix = prefix
      @auth_tables = {
        :digest => AuthTable.new,
        :basic => AuthTable.new
      }
    end

    def update_auth auth, client_opts
      # sanity check. This should be checked before we get here
      client_realm = client_opts[:realm]
      raise ArgumentError, "Internal error: realms do not match" if
        !client_realm.nil? && client_realm != auth.realm

      @auth_tables[auth.scheme][client_opts] = auth
    end

    def get_auth scheme, client_opts
      return @auth_tables[scheme][client_opts]
    end

    def <=> other
      self.prefix <=> other.prefix
    end
      
  end
  
  class AuthTable

    @@auth_keys = [:username, :password, :basic_creds,
                   :digest_a1, :realm, :digest_session]

    def [] opts
      auth = @tbl[extract_auth_values(opts)]
      return auth unless
        auth.nil? && opts.include?(:digest_session) && !File.zero?(opts[:digest_session])
      auth = DigestAuth.load opts[:digest_session]
      auth.username = opts[:username]
      auth.password = opts[:password]
      auth.h_a1 = opts[:digest_a1]
      auth
    rescue Errno::ENOENT
      nil
    end

    def []= opts, auth
      @tbl[extract_auth_values(opts)] = auth
      auth.dump_sans_creds opts[:digest_session] if opts.include? :digest_session
    end

    def initialize
      @tbl = {}
    end

    private

    def extract_auth_values opts
      opts.values_at *@@auth_keys 
    end

  end


    
end
