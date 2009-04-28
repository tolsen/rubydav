require 'rexml/document'
require 'test/unit'

require 'test/unit/unit_test_helper'

class CurrentUserPrivilegeSetTest < RubyDavUnitTestCase

  def setup
    super
    cups_str = <<EOS
<current-user-privilege-set xmlns='DAV:'> 
  <privilege><read/></privilege> 
  <privilege><write/></privilege> 
</current-user-privilege-set>
EOS
    @cups_elem = REXML::Document.new(cups_str).root

    @privileges = [RubyDav::PropKey.get('DAV:', 'read'),
                   RubyDav::PropKey.get('DAV:', 'write')]
  end
  
  def test_from_elem
    cups = RubyDav::CurrentUserPrivilegeSet.from_elem @cups_elem
    assert_instance_of RubyDav::CurrentUserPrivilegeSet, cups
    assert_equal @privileges, cups.privileges
  end
  

  def test_initialize
    cups = RubyDav::CurrentUserPrivilegeSet.new *@privileges
    assert_equal @privileges, cups.privileges
  end

  def test_property_result_class_reader
    cups_pk = RubyDav::PropKey.get 'DAV:', 'current-user-privilege-set'
    cups_result = RubyDav::PropertyResult.new cups_pk, '200', @cups_elem
    assert_instance_of(RubyDav::CurrentUserPrivilegeSet,
                       cups_result.current_user_privilege_set)
    assert_instance_of RubyDav::CurrentUserPrivilegeSet, cups_result.cups
  end


end
