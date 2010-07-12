require 'test/unit/unit_test_helper'

require 'lib/limestone'

class DomainMapTest < RubyDavUnitTestCase

  def assert_domain_map_matches xml
    assert_xml_matches xml do |xml|
      xml.xmlns! :lb => 'http://limebits.com/ns/1.0/'
      xml.lb :'domain-map' do
        [1, 2].each do |n|
        xml.lb :'domain-map-entry' do
            xml.lb :domain, "domain#{n}"
            xml.lb :path, "path#{n}"
          end
        end
      end
    end
  end

  def setup
    @domain_map = RubyDav::DomainMap.new('domain1' => 'path1',
                                         'domain2' => 'path2')
  end

  def test_from_elem
    domain_map_str = <<EOS
<lb:domain-map xmlns:lb='http://limebits.com/ns/1.0/'>
  <lb:domain-map-entry>
    <lb:domain>domain1</lb:domain>
    <lb:path>path1</lb:path>
  </lb:domain-map-entry>
  <lb:domain-map-entry>
    <lb:domain>domain2</lb:domain>
    <lb:path>path2</lb:path>
  </lb:domain-map-entry>
</lb:domain-map>
EOS
    domain_map_elem =
      LibXML::XML::Document.string(domain_map_str).root

    domain_map = RubyDav::DomainMap.from_elem domain_map_elem

    assert_equal @domain_map, domain_map
  end

  def test_initialize
    assert_equal([['domain1', 'path1'], ['domain2', 'path2']],
                 @domain_map.to_a.sort)
  end

  def test_to_xml
    assert_domain_map_matches @domain_map.to_xml 
  end

  def test_to_inner_xml
    full_xml = "<lb:domain-map xmlns:lb='http://limebits.com/ns/1.0/'>" +
      @domain_map.to_inner_xml + "</lb:domain-map>"

    assert_domain_map_matches full_xml
  end

end

  
