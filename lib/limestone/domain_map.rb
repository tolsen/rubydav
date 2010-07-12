require File.dirname(__FILE__) + '/constants'
require File.dirname(__FILE__) + '/../rubydav/property_result'

module RubyDav

  class DomainMap

    attr_reader :entries

    def == other
      other.is_a?(DomainMap) && entries == other.entries
    end

    alias :eql? :==

    def initialize *entries
      @entries = entries
    end

    def to_inner_xml
      @entries.map { |e| e.to_xml }.join("\n")
    end

    def to_xml xml = nil
      return RubyDav.build_xml(xml) do |xml, namespaces|
        namespaces['xmlns:lb'] = LIMEBITS_NS
        xml.lb :'domain-map', namespaces do
          @entries.each { |e| e.to_xml xml }
        end
      end
    end

    class << self
      
      def from_elem elem
        RubyDav.assert_elem_name elem, 'domain-map', LIMEBITS_NS
        entries = RubyDav.elements_named(elem, 'domain-map-entry',
                                         LIMEBITS_NS).map do |e|
          DomainMapEntry.from_elem e
        end
        
        return new(*entries)
      end
      
    end

    PropertyResult.define_class_reader(:domain_map, self,
                                       'domain-map', LIMEBITS_NS)
  end

  
  class DomainMapEntry

    attr_reader :domain, :path

    def == other
      other.is_a?(DomainMapEntry) &&
        domain == other.domain &&
        path == other.path
    end

    alias :eql? :==

    def initialize domain, path
      @domain = domain
      @path = path
    end

    def to_xml xml = nil
      return RubyDav.build_xml(xml) do |xml, namespaces|
        namespaces['xmlns:lb'] = LIMEBITS_NS
        xml.lb :'domain-map-entry', namespaces do
          xml.lb :domain, domain
          xml.lb :path, path
        end
      end
    end

    class << self

      def from_elem elem
        domain_elem = RubyDav.first_element_named elem, 'domain', LIMEBITS_NS
        path_elem = RubyDav.first_element_named elem, 'path', LIMEBITS_NS

        return new(domain_elem.content, path_elem.content)
      end
    end
  end
  
end
