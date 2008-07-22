require 'rexml/document'

module REXML
  class Element < Parent
    
    # EMPTY_NAMESPACE_PREFIX_DECLARATION_FIX
    
    # If an XML document includes an empty
    # namespace prefix declaration (xmlns:ns1=""), then a
    # ParseException should be raised.
    # http://www.w3.org/TR/REC-xml-names#dt-prefix
    
    alias_method :add_element_orig, :add_element
    private :add_element_orig
    def add_element element,attrs=nil
      if attrs.kind_of? Hash
        attrs.each do |key,value|
          raise ParseException.new("Empty Namespace Prefix Declaration") if ((key =~ /^xmlns:/) and (value == ""))
        end
      end
      add_element_orig element,attrs
    end
    # END EMPTY_NAMESPACE_PREFIX_DECLARATION_FIX
    
    def to_s_with_ns
      copy = self.deep_clone
      copy.parent = self.parent

      # in later REXML versions, namespaces is a hash
      if copy.namespaces.is_a? Hash
        
        copy.namespaces.each_pair do |k, v|
          copy.add_namespace k, v
        end

      else
        
        copy.attributes.prefixes.each do |p|
          copy.add_namespace p, copy.attributes["xmlns:#{p}"]
        end

      end
        
      copy.to_s
    end

    def inner_xml
      map do |e|
        if e.is_a? Element
          e.to_s_with_ns
        else
          e.to_s
        end
      end.join
    end

    #Set contents of an element from the source string 
    def innerXML= source
      Parsers::TreeParser.new(source,self).parse
    end
  end

  if (VERSION.split('.') <=> "3.1.7.1".split('.')) >= 0

    module Node

      def to_s indent=nil
        unless indent.nil?
#          Kernel.warn( "#{self.class.name}.to_s(indent) parameter is deprecated" )
          f = REXML::Formatters::Pretty.new( indent )
        else
          f = REXML::Formatters::Default.new
        end
        f.write( self, rv = "" )
        return rv
      end
    end
  end

end

