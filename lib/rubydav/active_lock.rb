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

        children = RubyDav.dav_elements_hash(elem, 'locktype', 'lockscope',
                                             'depth', 'owner', 'timeout',
                                             'locktoken', 'lockroot')

        required_elements = %w(locktype lockscope depth)
        raise ArgumentError if
          children.values_at(*required_elements).any? { |v| v.nil? }

        type = RubyDav.first_element(children['locktype']).name.to_sym
        scope = RubyDav.first_element(children['lockscope']).name.to_sym
        depth = parse_depth children['depth']

        # These elements are optional inside of DAV:activelock
        # (DAV:lockroot was introduced in RFC 4918)
        owner = timeout = token = root = nil

        owner = RubyDav.inner_xml_copy(children['owner']).strip if
          children.include? 'owner'

        timeout = parse_timeout(children['timeout']) if
          children.include? 'timeout'

        token = parse_element_with_href(children['locktoken']) if
          children.include? 'locktoken'

        root = parse_element_with_href(children['lockroot']) if
          children.include? 'lockroot'

        return new(type, scope, depth, timeout, owner, token, root)
      end
        
      def parse_element_with_href element
        href_elem = RubyDav.first_element_named element, 'href'
        raise ArgumentError if href_elem.nil?
        return href_elem.content.strip
      end

      def parse_depth depth_element
        depth_text = depth_element.content
        return case depth_text
               when '0', '1' then depth_text.to_i
               when 'infinity' then INFINITY
               else raise ArgumentError
               end
      end

      def parse_timeout(timeout)
        timeout = timeout.content
        return case timeout
               when /Second-\d+/ then timeout.split('-')[1].to_i
               when /Infinite/ then INFINITY
               else raise ArgumentError
               end
      end

    end
  end
end
    
