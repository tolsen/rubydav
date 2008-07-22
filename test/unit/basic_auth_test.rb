require 'test/test_helper'

class BasicAuthTestCase < Test::Unit::TestCase

  include RubyDav

  def setup
    @basic_auth = Auth.construct 'Basic realm="Lawson Restricted Access"'
  end 
  

  def test_construct_basic_auth
    assert_instance_of BasicAuth, @basic_auth
    assert_equal "Lawson Restricted Access", @basic_auth.realm
    assert_equal :basic, @basic_auth.scheme
  end

  def test_basic_authorization_user_pw
    @basic_auth.username = 'tim'
    @basic_auth.password = 'swordfish'
    assert_nothing_raised(RuntimeError) do
      assert_equal 'Basic dGltOnN3b3JkZmlzaA==', @basic_auth.authorization
    end
  end

  def test_basic_authorization_any_number_of_args
    @basic_auth.username = 'tim'
    @basic_auth.password = 'swordfish'

    args = []
    %w(foo bar baz).each do |arg|
      args.push arg
      assert_nothing_raised(ArgumentError) { @basic_auth.authorization args }
    end
  end

  def test_basic_authorization_creds
    @basic_auth.creds = 'dGltOnN3b3JkZmlzaA=='
    assert_nothing_raised(RuntimeError) do
      assert_equal 'Basic dGltOnN3b3JkZmlzaA==', @basic_auth.authorization
    end
  end
  
  def test_basic_authorization_nothing_set
    assert_raises(RuntimeError) { @basic_auth.authorization }
  end

  def test_basic_authorization_missing_username
    @basic_auth.password = 'swordfish'
    assert_raises(RuntimeError) { @basic_auth.authorization }
  end

  def test_basic_authorization_missing_password
    @basic_auth.username = 'tim'
    assert_raises(RuntimeError) { @basic_auth.authorization }
  end

end
