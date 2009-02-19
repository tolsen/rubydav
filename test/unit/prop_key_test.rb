require 'test/unit/unit_test_helper'

class RubyDavPropKeyTest < RubyDavUnitTestCase

  def test_compare
    pk1 = RubyDav::PropKey.get 'ns_a', 'name1'
    pk2 = RubyDav::PropKey.get 'ns_b', 'name2'
    pk3 = RubyDav::PropKey.get 'ns_b', 'name3'
    pk4 = RubyDav::PropKey.get 'ns_c', 'name0'

    assert pk1 < pk2
    assert pk2 < pk3
    assert pk3 < pk4
    assert pk1 < pk4
  end
  
  def test_get
    propkey = RubyDav::PropKey.get "http://www.example.org/mynamespace","myprop"
    assert_instance_of RubyDav::PropKey, propkey
  end

  def test_get__fails_when_name_has_right_brace
    assert_raises(RuntimeError) { RubyDav::PropKey.get 'ns', 'foo}bar' }
  end

  def test_get_gives_different_objects
    propkey1 = RubyDav::PropKey.get "namespace", "name"
    propkey2 = RubyDav::PropKey.get "namespacen", "ame"
    assert_not_equal propkey1, propkey2
  end
  
  def test_get_gives_same_object
    propkey1 = RubyDav::PropKey.get "DAV:","myprop"
    propkey2 = RubyDav::PropKey.get "DAV:","myprop"
    assert_equal true, propkey1.object_id == propkey2.object_id
  end
  
  def test_ns
    propkey = RubyDav::PropKey.get "DAV:","myprop"
    assert_not_nil propkey.ns
    assert_equal "DAV:", propkey.ns
  end
  
  def test_name
    propkey = RubyDav::PropKey.get "DAV:","myprop"
    assert_not_nil propkey.name
    assert_equal "myprop", propkey.name
  end
  
  def test_name_symbol
    propkey = RubyDav::PropKey.get "DAV:",:myprop
    assert_not_nil propkey.name
    assert_equal "myprop", propkey.name
  end
  
  def test_register_symbol
    propkey1 = RubyDav::PropKey.get "http://www.example.org/mynamespace",:myprop
    propkey1.register_symbol(:myprop)
    
    propkey2 = RubyDav::PropKey.strictly_prop_key :myprop
    
    assert_equal true, propkey1.object_id == propkey2.object_id
  end
  
  def test_strictly_prop_key
    propkey1 = RubyDav::PropKey.get "http://www.example.org/mynamespace",:myprop
    propkey1.register_symbol :myprop
    
    propkey2 = RubyDav::PropKey.strictly_prop_key :myprop
    assert_equal true, propkey1.object_id == propkey2.object_id
    
    propkey2 = RubyDav::PropKey.strictly_prop_key propkey1
    assert_equal true, propkey1.object_id == propkey2.object_id
  end
  
  def test_strictly_prop_key_with_new_symbol
    propkey = RubyDav::PropKey.strictly_prop_key :property
    assert_equal "property", propkey.name
    assert_equal "DAV:", propkey.ns
  end
  
  def test_to_s
    propkey = RubyDav::PropKey.get "DAV:", "myprop"
    assert_equal "{DAV:}myprop", propkey.to_s
  end
  
  def test_equality
    propkey1 = RubyDav::PropKey.get "DAV:", "myprop"
    propkey2 = RubyDav::PropKey.get "DAV:", "myproperty"
    
    assert_equal false, propkey1==propkey2
    assert_equal true, propkey1==propkey1
    assert_equal true, propkey1.eql?(propkey1)
  end
  
  def test_dav?
    propkey1 = RubyDav::PropKey.get "DAV:", "myprop"
    propkey2 = RubyDav::PropKey.get "http://www.example.org/mynamespace", "myprop"

    assert !propkey2.dav?
    assert propkey1.dav?
  end
  
  def test_hash
    propkey1 = RubyDav::PropKey.get "DAV:", "myprop"
    propkey2 = RubyDav::PropKey.get "DAV:", "myprop"

    assert_equal propkey1.hash, propkey2.hash

    propkey3 = RubyDav::PropKey.get "http://www.example.org/mynamespace", "myprop"
    propkey4 = RubyDav::PropKey.get "http://www.example.org/mynamespace", "myprop"

    assert_equal propkey3.hash, propkey4.hash
    assert_not_equal propkey1.hash, propkey4.hash
  end

  def generate_and_assert_propkey_xml propkey, expected_xml
    assert (normalized_rexml_equal expected_xml, propkey.printXML)
  end
  
  def test_printXML_with_DAV
    propkey = RubyDav::PropKey.get "DAV:", "myprop"
    expected_xml = "<D:myprop xmlns:D='DAV:'/>"
    generate_and_assert_propkey_xml propkey, expected_xml
  end
  
  def test_printXML
    propkey = RubyDav::PropKey.get "http://www.example.org/mynamespace", "myprop"
    expected_xml = "<R:myprop xmlns:R=\"http://www.example.org/mynamespace\"/>"
    generate_and_assert_propkey_xml propkey, expected_xml
  end
  
  def generate_and_assert_propkey_xml_with_value propkey, value, expected_xml
    propkey_xml = propkey.printXML nil, value
    assert normalized_rexml_equal(expected_xml, propkey_xml)
  end
  
  def test_printXML_with_value_with_DAV
    propkey = RubyDav::PropKey.get "DAV:", "myprop"
    expected_xml = "<D:myprop xmlns:D='DAV:'>myvalue</D:myprop>"
    generate_and_assert_propkey_xml_with_value propkey, "myvalue", expected_xml
  end
  
  def test_printXML_with_value
    propkey = RubyDav::PropKey.get "http://www.example.org/mynamespace", "myprop"
    expected_xml = "<R:myprop xmlns:R=\"http://www.example.org/mynamespace\">myvalue</R:myprop>"
    generate_and_assert_propkey_xml_with_value propkey, "myvalue", expected_xml
  end
end
