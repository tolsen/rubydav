require 'test/unit/unit_test_helper'

class LockEntryTest < RubyDavUnitTestCase

  def test_from_elem
    xml = <<EOS
<D:lockentry xmlns:D='DAV:'> 
  <D:lockscope><D:shared/></D:lockscope> 
  <D:locktype><D:write/></D:locktype> 
</D:lockentry>
EOS
    elem = body_root_element xml
    entry = RubyDav::LockEntry.from_elem elem
    assert_instance_of RubyDav::LockEntry, entry
    assert_equal :write, entry.type
    assert_equal :shared, entry.scope
  end

  bad_xmls = {}

  bad_xmls[:bad_root] = <<EOS
<D:badlockentry xmlns:D='DAV:'> 
  <D:lockscope><D:shared/></D:lockscope> 
  <D:locktype><D:write/></D:locktype> 
</D:badlockentry>
EOS

  bad_xmls[:missing_scope] = <<EOS
<D:lockentry xmlns:D='DAV:'> 
  <D:locktype><D:write/></D:locktype> 
</D:lockentry>
EOS

  bad_xmls[:missing_type] = <<EOS
<D:lockentry xmlns:D='DAV:'> 
  <D:lockscope><D:shared/></D:lockscope> 
</D:lockentry>
EOS

  bad_xmls[:empty_scope] = <<EOS
<D:lockentry xmlns:D='DAV:'> 
  <D:lockscope></D:lockscope> 
  <D:locktype><D:write/></D:locktype> 
</D:lockentry>
EOS

  bad_xmls[:empty_type] = <<EOS
<D:lockentry xmlns:D='DAV:'> 
  <D:lockscope><D:shared/></D:lockscope> 
  <D:locktype></D:locktype> 
</D:lockentry>
EOS

  bad_xmls.each do |suffix, xml|
    define_method "test_from_elem__#{suffix}".to_sym do
      elem = body_root_element xml
      assert_raises(ArgumentError) { RubyDav::LockEntry.from_elem elem }
    end
  end

  def test_initialize
    entry = RubyDav::LockEntry.new :write, :exclusive
    assert_equal :write, entry.type
    assert_equal :exclusive, entry.scope
  end

end
