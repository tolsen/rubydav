require 'test/unit/unit_test_helper'

class AceTest < RubyDavUnitTestCase

  def test_generalize_principal
    principal = 'http://neurofunk.limewire.com:8080/users/bits'
    assert_equal '/users/bits', RubyDav.generalize_principal(principal)
  end

  def test_generalize_principal__already_general
    assert_equal '/users/bits', RubyDav.generalize_principal('/users/bits')
  end
  
end
