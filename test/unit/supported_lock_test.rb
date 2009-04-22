require 'test/unit/unit_test_helper'

class SupportedLockTest < RubyDavUnitTestCase

  def setup
    super
    xml = <<EOS
<D:supportedlock xmlns:D='DAV:'> 
  <D:lockentry> 
    <D:lockscope><D:exclusive/></D:lockscope> 
    <D:locktype><D:write/></D:locktype> 
  </D:lockentry> 
  <D:lockentry> 
    <D:lockscope><D:shared/></D:lockscope> 
    <D:locktype><D:write/></D:locktype> 
  </D:lockentry> 
</D:supportedlock> 
EOS
    @supported_lock_elem = body_root_element xml
  end

  def test_from_elem
    supported_lock = RubyDav::SupportedLock.from_elem @supported_lock_elem

    assert_instance_of RubyDav::SupportedLock, supported_lock
    assert_equal 2, supported_lock.entries.size

    supported_lock.entries.each do |e|
      assert_instance_of RubyDav::LockEntry, e
      assert_equal :write, e.type
    end

    assert_equal :exclusive, supported_lock.entries[0].scope
    assert_equal :shared, supported_lock.entries[1].scope
  end

  def test_from_elem__bad_root
    xml = <<EOS
<D:badsupportedlock xmlns:D='DAV:'> 
  <D:lockentry> 
    <D:lockscope><D:exclusive/></D:lockscope> 
    <D:locktype><D:write/></D:locktype> 
  </D:lockentry> 
  <D:lockentry> 
    <D:lockscope><D:shared/></D:lockscope> 
    <D:locktype><D:write/></D:locktype> 
  </D:lockentry> 
</D:badsupportedlock> 
EOS
    elem = body_root_element xml
    assert_raises(ArgumentError) { RubyDav::SupportedLock.from_elem elem }
  end
  
  def test_initialize
    supported_lock = RubyDav::SupportedLock.new :entry1, :entry2
    assert_equal [:entry1, :entry2], supported_lock.entries
  end

  def test_property_result_class_reader
    sl_pk = RubyDav::PropKey.get 'DAV:', 'supportedlock'
    result = RubyDav::PropertyResult.new sl_pk, '200', @supported_lock_elem
    assert_instance_of RubyDav::SupportedLock, result.supportedlock
  end
  
end
