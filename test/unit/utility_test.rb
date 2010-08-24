require 'test/unit/unit_test_helper'

class UtilityTest < RubyDavUnitTestCase

  def test_first_element_named
    str = '<a xmlns="DAV:"><b/><c/></a>'
    root = LibXML::XML::Document.string(str).root
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
    root = LibXML::XML::Document.string('<a xmlns="DAV:"><b><c><d/></c></b></a>').root

    assert_equal 'b', RubyDav.get_dav_descendent(root, 'b').name
    assert_equal 'c', RubyDav.get_dav_descendent(root, 'b', 'c').name
    assert_equal 'd', RubyDav.get_dav_descendent(root, 'b', 'c', 'd').name
    assert_nil RubyDav.get_dav_descendent(root, 'c')
    assert_nil RubyDav.get_dav_descendent(root, 'b', 'd')
  end

  def test_inner_xml_copy__text_node
    root = LibXML::XML::Document.string('<a>b</a>').root
    assert_equal 'b', RubyDav.inner_xml_copy(root)
  end

  def test_inner_xml_copy__text_node_escaping_off
    root = LibXML::XML::Document.string('<a>&amp;</a>').root
    root.output_escaping = false
    assert_equal '&', RubyDav.inner_xml_copy(root)
  end
  
  
end
