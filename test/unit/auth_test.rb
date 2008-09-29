require 'test/test_helper'

class AuthTestCase < Test::Unit::TestCase

  include RubyDav

  def test_scheme
    assert_nil Auth.new('realm').scheme
  end

end
