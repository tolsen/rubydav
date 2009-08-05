module RubyDav

  class ActiveLock

    attr_reader :scope, :type, :depth, :owner, :timeout, :token, :root

    # does not check that root is equal
    def eql? other
      return other.is_a?(ActiveLock) &&
        self.scope == other.scope &&
        self.type == other.type &&
        self.depth == other.depth &&
        ((self.owner.nil? && other.owner.nil?) ||
         (!self.owner.nil? && !other.owner.nil? &&
          self.owner.strip == other.owner.strip)) &&
        self.timeout == other.timeout &&
        self.token == other.token
    end

    alias == eql?

    def initialize type, scope, depth, timeout, owner, token, root
      @type = type
      @scope = scope
      @depth = depth
      @timeout = timeout
      @owner = owner
      @token = token
      @root = root
    end
      
    class << self

      def from_elem elem
        RubyDav.assert_elem_name elem, 'activelock'

        al_elements =
          [:locktype, :lockscope, :depth, :owner,
           :timeout, :locktoken, :lockroot].inject({}) do |h, k|
          h[k] = RubyDav.xpath_first elem, k.to_s
          next h
        end

        required_elements = [ :locktype, :lockscope, :depth ]
        raise ArgumentError if
          al_elements.values_at(*required_elements).any? { |v| v.nil? }

        type = al_elements[:locktype].elements[1].name.to_sym
        scope = al_elements[:lockscope].elements[1].name.to_sym
        depth = parse_depth al_elements[:depth]

        # These elements are optional inside of DAV:activelock
        # (DAV:lockroot was introduced in RFC 4918)
        owner = timeout = token = root = nil

        owner = al_elements[:owner].inner_xml.to_s.strip unless
          al_elements[:owner].nil?

        timeout = parse_timeout(al_elements[:timeout]) unless
          al_elements[:timeout].nil?

        token = parse_element_with_href(al_elements[:locktoken]) unless
          al_elements[:locktoken].nil?

        root = parse_element_with_href(al_elements[:lockroot]) unless
          al_elements[:lockroot].nil?

        return new(type, scope, depth, timeout, owner, token, root)
      end
        
      def parse_element_with_href(element)
        href = RubyDav.xpath_first element, "href"
        raise ArgumentError if href.nil?
        return href.text.strip
      end

      def parse_depth depth_element
        depth_text = depth_element.text.strip
        return case depth_text
               when '0', '1' then depth_text.to_i
               when 'infinity' then INFINITY
               else raise ArgumentError
               end
      end

      def parse_timeout(timeout)
        timeout = timeout.text.strip
        return case timeout
               when /Second-\d+/ then timeout.split('-')[1].to_i
               when /Infinite/ then INFINITY
               else raise ArgumentError
               end
      end
      
    end
  end
end
    
