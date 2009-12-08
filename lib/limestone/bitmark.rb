module RubyDav

  class Bitmark

    unless defined? BITMARKS_ROOT
      BITMARKS_ROOT = '/bitmarks'
      BITMARK_NS = 'http://limebits.com/ns/bitmarks/1.0/'

      include Comparable

      attr_reader :name, :value, :owner

      # the url for the collection at which the bitmark is stored
      # The url is of the form /bitmarks/<uuid>/col
      attr_reader :url

      def initialize name, value, owner, url = nil
        @name = name
        @value = value
        @owner = owner
        @url = url
      end

      def <=> other
        return 1 unless other.is_a? Bitmark

        attrs = [:name, :value, :owner]

        attrs.each do |attr|
          attr_value = send attr
          other_attr_value = other.send attr
          return(attr_value <=> other_attr_value) unless
            attr_value == other_attr_value
        end

        return url <=> other.url unless url.nil? || other.url.nil?

        # nil urls sort before non-nil urls
        if url.nil?
          return other.url.nil? ? 0 : -1
        else
          # other.url must be nil        
          raise "Internal Error" unless other.url.nil?
          return 1  
        end
      end
    end
  end

end
