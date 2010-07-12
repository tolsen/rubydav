require 'test/unit/unit_test_helper'

class RubyDavPropKeyTest < RubyDavUnitTestCase

  def assert_xml_equal expected_xml, actual_xml
    assert(xml_equal?(expected_xml, actual_xml),
           "expected\n\n#{actual_xml}\n\nto be equal to\n\n#{expected_xml}")
  end

  def generate_and_assert_propkey_xml propkey, expected_xml
    assert_xml_equal expected_xml, propkey.to_xml
  end
  
  def generate_and_assert_propkey_xml_with_value propkey, value, expected_xml
    propkey_xml = propkey.to_xml nil, value
    assert_xml_equal expected_xml, propkey_xml
  end

  def setup
    super

    @myprop_pk = RubyDav::PropKey.get "DAV:", "myprop"
  end
  
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
  
  def test_dav?
    propkey2 = RubyDav::PropKey.get "http://www.example.org/mynamespace", "myprop"

    assert !propkey2.dav?
    assert @myprop_pk.dav?
  end
  
  def test_equality
    propkey2 = RubyDav::PropKey.get "DAV:", "myproperty"
    
    assert !(@myprop_pk==propkey2)
    assert @myprop_pk==@myprop_pk
    assert @myprop_pk.eql?(@myprop_pk)
  end

  # Although PropKey follows a flyweight pattern, it is currently
  # possible to get different ids if a PropKey is marshalled out and back
  # we emulate that here by using send to call new()
  def test_equality__different_ids
    pk1 = RubyDav::PropKey.send :new, 'DAV:', 'myprop'
    pk2 = RubyDav::PropKey.send :new, 'DAV:', 'myprop'

    assert_not_equal pk1.object_id, pk2.object_id
    assert (pk1 == pk2)
    assert (pk2 == pk1)
    assert pk1.eql?(pk2)
    assert pk2.eql?(pk1)
  end
    
  def test_get
    propkey = RubyDav::PropKey.get "http://www.example.org/mynamespace","myprop"
    assert_instance_of RubyDav::PropKey, propkey
  end

  def test_get__fails_when_name_has_right_brace
    assert_raises(RuntimeError) { RubyDav::PropKey.get 'ns', 'foo}bar' }
  end

  def test_get__gives_different_objects
    propkey1 = RubyDav::PropKey.get "namespace", "name"
    propkey2 = RubyDav::PropKey.get "namespacen", "ame"
    assert_not_equal propkey1, propkey2
  end
  
  def test_get__gives_same_object
    propkey2 = RubyDav::PropKey.get "DAV:","myprop"
    assert_equal @myprop_pk.object_id, propkey2.object_id
  end
  
  def test_hash
    propkey2 = RubyDav::PropKey.get "DAV:", "myprop"

    assert_equal @myprop_pk.hash, propkey2.hash

    propkey3 = RubyDav::PropKey.get "http://www.example.org/mynamespace", "myprop"
    propkey4 = RubyDav::PropKey.get "http://www.example.org/mynamespace", "myprop"

    assert_equal propkey3.hash, propkey4.hash
    assert_not_equal @myprop_pk.hash, propkey4.hash
  end

  def test_name
    assert_not_nil @myprop_pk.name
    assert_equal "myprop", @myprop_pk.name
  end
  
  def test_name__symbol
    propkey = RubyDav::PropKey.get "DAV:",:myprop
    assert_not_nil propkey.name
    assert_equal "myprop", propkey.name
  end
  
  def test_ns
    assert_not_nil @myprop_pk.ns
    assert_equal "DAV:", @myprop_pk.ns
  end
  
  def test_to_xml
    propkey = RubyDav::PropKey.get "http://www.example.org/mynamespace", "myprop"
    expected_xml = "<R:myprop xmlns:R=\"http://www.example.org/mynamespace\"/>"
    generate_and_assert_propkey_xml propkey, expected_xml
  end
  
  def test_to_xml__with_DAV
    expected_xml = "<D:myprop xmlns:D='DAV:'/>"
    generate_and_assert_propkey_xml @myprop_pk, expected_xml
  end
  
  def test_to_xml__with_value
    propkey = RubyDav::PropKey.get "http://www.example.org/mynamespace", "myprop"
    expected_xml = "<R:myprop xmlns:R=\"http://www.example.org/mynamespace\">myvalue</R:myprop>"
    generate_and_assert_propkey_xml_with_value propkey, "myvalue", expected_xml
  end

  def test_to_xml__with_value_with_DAV
    expected_xml = "<D:myprop xmlns:D='DAV:'>myvalue</D:myprop>"
    generate_and_assert_propkey_xml_with_value @myprop_pk, "myvalue", expected_xml
  end

  def test_to_xml__with_symbol_value
    expected_xml = "<D:myprop xmlns:D='DAV:'>\n<D:foo/>\n</D:myprop>"
    generate_and_assert_propkey_xml_with_value @myprop_pk, :"<D:foo/>", expected_xml
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
  
  def test_strictly_prop_key__with_new_symbol
    propkey = RubyDav::PropKey.strictly_prop_key :property
    assert_equal "property", propkey.name
    assert_equal "DAV:", propkey.ns
  end
  
  def test_to_s
    assert_equal "{DAV:}myprop", @myprop_pk.to_s
  end
  
end
