module RubyDav
  
  # Property keys
  class PropKey

    include Comparable

    #--
    # List of all supported DAV: properties.
    # DAV_PROPERTIES = %w{getcontentlength   getcontenttype   creationdate
    #                     getlastmodified    displayname      resourcetype
    #                     getcontentlanguage getetag          lockdiscovery
    #                     source             supportedlock    owner
    #                     acl}
    #++
    
    attr_reader :ns, :name
    @@keys = {}
    @@registeredkeys = {}
    
    # Returns a PropKey  (Flyweight Pattern)
    def self.get ns, name
      name = name.to_s if name.is_a?(Symbol)
      raise "'}' not allowed in property name" if name['}']

      key4key = ns_and_name_str(ns, name).to_sym
      return (@@keys[key4key] ||= new(ns, name))
    end

    def self.ns_and_name_str ns, name
      "{#{ns}}#{name}"
    end
    
    # returns PropKey given PropKey or Symbol or String
    def self.strictly_prop_key propkey_or_symbol
      return propkey_or_symbol unless
        propkey_or_symbol.is_a?(Symbol) || propkey_or_symbol.is_a?(String)
      return @@registeredkeys[propkey_or_symbol] if
        @@registeredkeys.include? propkey_or_symbol
      return self.get("DAV:", propkey_or_symbol)
    end
    
    # registers a PropKey to have alias <tt>symbol</tt>
    def register_symbol symbol
      @@registeredkeys[symbol] = self
    end
    
    def to_s
      self.class.ns_and_name_str ns, name
    end

    def to_sym
      return name.to_sym if dav?
      
      return @@registeredkeys.keys.detect do |sym|
        @@registeredkeys[sym] == self
      end
    end

    def <=> other
      return 1 unless other.is_a?(PropKey)
      return @name <=> other.name if @ns == other.ns
      return @ns <=> other.ns
    end

    alias_method :eql?, :==
      
    def dav?
      @ns == "DAV:"
    end

    # String values are escaped
    # Symbol values are not escaped
    def to_xml(xml = nil, value=nil)
      # output the prop element for the propkey
      value = value.nil? ? "" : value

      return RubyDav::build_xml(xml) do |xml, ns|
        escape = true

        # one of the ways to check if value is a XmlMarkup,
        # standard is_a? does not work.
        begin
          value = value.target!
          escape = false
        rescue NoMethodError
          escape = !value.is_a?(Symbol)
        end

        if escape
          
          if @ns == "DAV:"
            xml.D(@name.to_sym, value.to_s, ns)
          else
            xml.R(@name.to_sym, value.to_s, "xmlns:R" => @ns )
          end
          
        else
          
          if @ns == "DAV:"
            xml.D(@name.to_sym, ns) {xml << value.to_s } 
          else
            xml.R(@name.to_sym, "xmlns:R" => @ns) { xml << value.to_s }
          end

        end
        
      end
    end
    
    def hash
      to_s.hash
    end
    
    def initialize(ns, name)
      @ns = ns
      @name = name
    end
    
    private_class_method :new    
  end
  
end

