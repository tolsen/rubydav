require File.dirname(__FILE__) + '/constants'
require File.dirname(__FILE__) + '/../rubydav/property_result'

module RubyDav

  class DomainMap < Hash

    def initialize hsh = {}
      merge! hsh
    end

    def to_inner_xml
      map { |d, p| self.class.entry_to_xml d, p }.join("\n")
    end

    def to_xml xml = nil
      return RubyDav.build_xml(xml) do |xml, namespaces|
        namespaces['xmlns:lb'] = LIMEBITS_NS
        xml.lb :'domain-map', namespaces do
          each { |d, p| self.class.entry_to_xml d, p, xml }
        end
      end
    end
    

    class << self

      def entry_to_xml domain, path, xml = nil
        return RubyDav.build_xml(xml) do |xml, namespaces|
          namespaces['xmlns:lb'] = LIMEBITS_NS
          xml.lb :'domain-map-entry', namespaces do
            xml.lb :domain, domain
            xml.lb :path, path
          end
        end
      end

      def from_elem elem
        RubyDav.assert_elem_name elem, 'domain-map', LIMEBITS_NS
        dm = new
        
        RubyDav.elements_named(elem, 'domain-map-entry',
                                     LIMEBITS_NS).each do |e|
          domain_elem = RubyDav.first_element_named e, 'domain', LIMEBITS_NS
          path_elem = RubyDav.first_element_named e, 'path', LIMEBITS_NS
          dm[domain_elem.content] = path_elem.content
        end
        
        return dm
      end

    end

    PropertyResult.define_class_reader(:domain_map, self,
                                       'domain-map', LIMEBITS_NS)
    
  end
  
end
