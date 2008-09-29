module RubyDav
  
  # Property keys
  class PropKey

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
      @@keys[ns + name] = new(ns, name) if @@keys[ns + name].nil?
      @@keys[ns + name]
    end
    
    # returns PropKey given PropKey or Symbol
    def self.strictly_prop_key propkey_or_symbol
      if propkey_or_symbol.is_a?(Symbol)
        if(@@registeredkeys[propkey_or_symbol])
          propkey_or_symbol = @@registeredkeys[propkey_or_symbol]
        else
          propkey_or_symbol = self.get("DAV:",propkey_or_symbol.to_s)
        end
      end
      propkey_or_symbol
    end
    
    
    # registers a PropKey to have alias <tt>symbol</tt>
    def register_symbol symbol
      @@registeredkeys[symbol] = self
    end
    
    def to_s
      "#{@ns}#{@name}"
    end
 
    #FIXME: Registered Symbols cannot be sent to == as of now
    def == other
   #   other = PropKey.strictly_prop_key(other) if Symbol === other 	
      return false unless PropKey === other
      @ns == other.ns && @name == other.name
    end
    alias eql? ==
      
    def dav?
      @ns == "DAV:"
    end
    
    def printXML(xml = nil, value=:remove)
      # output the prop element for the propkey
      value = (:remove == value) ? "" : value

      return RubyDav::buildXML(xml) do |xml, ns|

        # one of the ways to check if value is a XmlMarkup,
        # standard is_a? does not work.
        # if value.is_a? ::Builder::XmlMarkup
        begin
          valxml = value.target!
          if @ns == "DAV:"
            xml.D(@name.to_sym, *ns) {xml << valxml } 
          else
            xml.R(@name.to_sym, "xmlns:R" => @ns) { xml << valxml }
          end
        rescue NoMethodError
          if @ns == "DAV:"
            xml.D(@name.to_sym, value.to_s, *ns)
          else
            xml.R(@name.to_sym, value.to_s, "xmlns:R" => @ns )
          end
        end
      end
    end
    
    def hash
      hashval = "{#{@ns}}#{@name}".hash
      hashval = "#{@ns}#{@name}".hash if @ns == "DAV:"
      hashval
    end
    
    def initialize(ns, name)
      @ns = ns
      @name = name
    end
    
    private_class_method :new    
  end
  
end

