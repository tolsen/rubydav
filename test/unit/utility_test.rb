require 'test/unit/unit_test_helper'

class UtilityTest < RubyDavUnitTestCase

  def test_first_element_named
    str = '<a xmlns="DAV:"><b/><c/></a>'
    root = Nokogiri::XML::Document.parse(str).root
    elem = RubyDav.first_element_named root, 'b'
    assert_equal 'b', elem.name
  end

  def test_generalize_principal
    principal = 'http://neurofunk.limewire.com:8080/users/bits'
    assert_equal '/users/bits', RubyDav.generalize_principal(principal)
  end

  def test_generalize_principal__already_general
    assert_equal '/users/bits', RubyDav.generalize_principal('/users/bits')
  end

  def test_get_dav_descendant
    root = Nokogiri::XML::Document.parse('<a xmlns="DAV:"><b><c><d/></c></b></a>').root

    assert_equal 'b', RubyDav.get_dav_descendent(root, 'b').name
    assert_equal 'c', RubyDav.get_dav_descendent(root, 'b', 'c').name
    assert_equal 'd', RubyDav.get_dav_descendent(root, 'b', 'c', 'd').name
    assert_nil RubyDav.get_dav_descendent(root, 'c')
    assert_nil RubyDav.get_dav_descendent(root, 'b', 'd')
  end

  def test_inner_xml_copy__text_node
    root = Nokogiri::XML::Document.parse('<a>b</a>').root
    assert_equal 'b', RubyDav.inner_xml_copy(root)
  end

  def test_xml_lang__declared_on_element
    root = body_root_element "<root xml:lang='es'/>"
    assert_equal "es", RubyDav.xml_lang(root)
  end

  def test_xml_lang__declared_on_parent
    root = body_root_element "<root xml:lang='fr'><child/></root>"
    child = RubyDav.first_element_named root, "child", nil
    assert_equal "fr", RubyDav.xml_lang(child)
  end

  def test_xml_lang__undeclared
    root = body_root_element "<root/>"
    assert_nil RubyDav.xml_lang(root)
  end

  # Not sure how to do this in Nokogiri
  # Appears to only be necessary to avoid double escaping
  # when sync'ing down bitmarks...
  
  # def test_inner_xml_copy__text_node_escaping_off
  #   root = Nokogiri::XML::Document.parse('<a>&amp;</a>').root
  #   root.output_escaping = false
  #   assert_equal '&', RubyDav.inner_xml_copy(root)
  # end
  
  
end
