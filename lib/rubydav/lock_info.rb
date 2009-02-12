module RubyDav
  class LockInfo
    attr_reader :type, :scope, :depth, :timeout, :owner, :token
    attr_accessor :root

    # FIXME: timeout and owner should not have default values
    # because they are optional elements in D:activelock
    def initialize(opts={})
      @type = opts[:type] || :write
      @scope = opts[:scope] || :exclusive
      @depth = opts[:depth] || INFINITY
      @timeout = opts[:timeout] || INFINITY
      @owner = opts[:owner] || "RubyDav Tests"
      @token = opts[:token]
      @root = opts[:root]
    end

    def printXML(xml)
      xml.D(:lockinfo, "xmlns:D" => "DAV:") do
        xml.D :locktype do
          xml.D @type
        end
        xml.D :lockscope do
          xml.D @scope
        end
        xml.D(:owner) { xml << @owner }
      end
    end

    class << self

      def from_lockdiscovery_element lockdiscovery_element
        raise ArgumentError unless
          lockdiscovery_element.namespace == "DAV:" &&
          lockdiscovery_element.name == "lockdiscovery"
        activelock = REXML::XPath.first(lockdiscovery_element, "D:activelock",
                                        {"D" => "DAV:"})

        al_elements =
          [:locktype, :lockscope, :depth, :owner,
           :timeout, :locktoken, :lockroot].inject({}) do |h, k|
          h[k] = REXML::XPath.first(activelock, "D:#{k}", {"D" => "DAV:"})
          next h
        end

        required_elements = [ :locktype, :lockscope, :depth ]
        raise ArgumentError if
          al_elements.values_at(*required_elements).any? { |v| v.nil? }

        opts = {
          :type => al_elements[:locktype].elements[1].name.to_sym,
          :scope => al_elements[:lockscope].elements[1].name.to_sym,
          :depth => parse_depth(al_elements[:depth]),
        }

        # These elements are optional inside of DAV:activelock
        # (DAV:lockroot was introduced in RFC 4918)
        opts[:owner] = al_elements[:owner].inner_xml.to_s.strip unless
          al_elements[:owner].nil?

        opts[:timeout] = parse_timeout(al_elements[:timeout]) unless
          al_elements[:timeout].nil?

        opts[:token] = parse_element_with_href(al_elements[:locktoken]) unless
          al_elements[:locktoken].nil?

        opts[:root] = parse_element_with_href(al_elements[:lockroot]) unless
          al_elements[:lockroot].nil?

        return RubyDav::LockInfo.new(opts)
      end
        
        

      def from_prop_element prop_element
        raise ArgumentError unless
          prop_element.namespace == "DAV:" && prop_element.name == "prop"
        lockdiscovery = REXML::XPath.first(prop_element, "D:lockdiscovery",
                                           {"D" => "DAV:"})
        return from_lockdiscovery_element(lockdiscovery)
      end

      def parse_element_with_href(element)
        href = REXML::XPath.first(element, "D:href", {"D" => "DAV:"})
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
