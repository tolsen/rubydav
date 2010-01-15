require File.dirname(__FILE__) + '/../rubydav.rb'
require File.dirname(__FILE__) + '/../limestone/bitmark.rb'


module RubyDav

  class BitmarkResponse < PropstatResponse

    attr_reader :bitmarks
    
    def initialize url, status, headers, body, resources
      super
      @bitmarks = []

      resources.each do |u, hsh|
        next unless u =~ /^#{url}\/[^\/]+$/
        owner = RubyDav.first_element_named(hsh[:owner].element, 'href').content
        hsh.each do |pk, pr|
          next unless pk.ns == Bitmark::BITMARK_NS && pr.status == '200'
          @bitmarks << Bitmark.new(pk.name, pr.inner_value, owner, u)
        end
      end

    end
  end

  ResponseFactory.map['207'][:propfind_bitmarks] = BitmarkResponse
  
end
