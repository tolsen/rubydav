require 'rexml/document'
require 'test/unit'

require 'test/unit/unit_test_helper'

class CurrentUserPrivilegeSetTest < RubyDavUnitTestCase

  def setup
    super
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
end
