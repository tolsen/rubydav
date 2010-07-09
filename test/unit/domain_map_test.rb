require 'test/unit/unit_test_helper'

require 'lib/limestone'

class DomainMapEntryTest < RubyDavUnitTestCase

  def setup
    super
    @entry = RubyDav::DomainMapEntry.new 'www.example.com', '/home/tim/example'
  end

  def test_eqeq__equal
    entry2 = RubyDav::DomainMapEntry.new 'www.example.com', '/home/tim/example'
    assert_equal @entry, entry2
  end

  def test_eqeq__not_equal
    entry2 = RubyDav::DomainMapEntry.new 'www.example2.com', '/home/tim/example'
    entry3 = RubyDav::DomainMapEntry.new 'www.example.com', '/home/tim/example2'

    assert_not_equal @entry, entry2
    assert_not_equal @entry, entry3
  end

  def test_from_elem
    domain_map_entry_str = <<EOS
<lb:domain-map-entry xmlns:lb='http://limebits.com/ns/1.0/'>
  <lb:domain>www.limelabs.com</lb:domain>
  <lb:path>/home/limelabs</lb:path>
</lb:domain-map-entry>
EOS
    domain_map_entry_elem =
      LibXML::XML::Document.string(domain_map_entry_str).root

    entry = RubyDav::DomainMapEntry.from_elem domain_map_entry_elem
    
    assert_equal 'www.limelabs.com', entry.domain
    assert_equal '/home/limelabs', entry.path
  end
  
  def test_initialize
    assert_equal 'www.example.com', @entry.domain
    assert_equal '/home/tim/example', @entry.path
  end

  def test_to_xml
    assert_xml_matches @entry.to_xml do |xml|
      xml.xmlns! :lb => 'http://limebits.com/ns/1.0/'
      xml.lb :'domain-map-entry' do
        xml.lb :domain, 'www.example.com'
        xml.lb :path, '/home/tim/example'
      end
    end
  end

end

class DomainMapTest < RubyDavUnitTestCase

  def setup
    @entry1 = RubyDav::DomainMapEntry.new 'domain1', 'path1'
    @entry2 = RubyDav::DomainMapEntry.new 'domain2', 'path2'

    @domain_map = RubyDav::DomainMap.new @entry1, @entry2
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

    assert_equal [@entry1, @entry2], domain_map.entries
  end

  def test_initialize
    assert_equal [@entry1, @entry2], @domain_map.entries
  end

  def test_to_xml
    assert_xml_matches @domain_map.to_xml do |xml|
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


end

  
