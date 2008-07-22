require 'test/unit/unit_test_helper'

class AuthWorldTest < RubyDavUnitTestCase

  include RubyDav

  def setup
    super

    @opts1 = {
      :base_url => 'http://example.com/',
      :username => 'tim',
      :password => 'swordfish',
      :realm => 'users@example.com'
    }

    @opts2 = {
      :base_url => 'http://example.com/',
      :username => 'chetan',
      :password => 'fishsword',
      :realm => 'users@example.com'
    }

    @opts3 = {
      :base_url => 'http://limebits.com/',
      :username => 'paritosh',
      :password => 'catfish',
      :realm => 'users@limebits.com'
    }

    @opts4 = {
      :base_url => 'http://limespot.com/',
      :username => 'jam',
      :password => 'dogfish',
      :realm => 'users@limespot.com'
    }

    @digest_auth = Auth.construct 'Digest realm="users@example.com", nonce="wPloasE7BAA=aa990a469b2526e74bf52add00efb83d96a17a56", algorithm=MD5, qop="auth"'
    @basic_auth = Auth.construct 'Basic realm="users@example.com"'

    @digest_auth_multiple_domains = Auth.construct 'Digest realm="users@limebits.com", nonce="wPloasE7BAA=aa990a469b2526e74bf52add00efb83d96a17a56", algorithm=MD5, qop="auth", domain="http://limebits.com/ https://limebits.com/ http://paritosh.limebits.com/"'

    @digest_auth_separate_path_domains = Auth.construct 'Digest realm="users@limespot.com", nonce="wPloasE7BAA=aa990a469b2526e74bf52add00efb83d96a17a56", algorithm=MD5, qop="auth", domain="/home/tim/ /home/jam/"'

  end
  
  def test_auth_world_prefix
    assert AuthWorld.prefix?('http://example.com/foo', 'http://example.com/foo')
    assert AuthWorld.prefix?('http://example.com/foo', 'http://example.com/foo/')

    assert AuthWorld.prefix?('http://example.com/', 'http://example.com/')
    assert AuthWorld.prefix?('http://example.com', 'http://example.com/')
    assert AuthWorld.prefix?('http://example.com/', 'http://example.com')

    assert AuthWorld.prefix?('http://example.com/', 'http://example.com/foo')
    assert AuthWorld.prefix?('http://example.com/foo', 'http://example.com/foo/bar')

    assert !AuthWorld.prefix?('http://example.com/foo', 'http://example2.com/foo')
    assert !AuthWorld.prefix?('http://example.com/foo/', 'http://example.com/foo')
    assert !AuthWorld.prefix?('http://example.com/foo/bar', 'http://example.com/foo')
    assert !AuthWorld.prefix?('http://example.com/foo/bar', 'http://example.com/foo/')
  end
  
  def test_ensure_trailing_slash_if_no_hierarchy
    assert_equal('http://example.com/',
                 AuthWorld.ensure_trailing_slash_if_no_hierarchy('http://example.com'))
    assert_equal('http://example.com/',
                 AuthWorld.ensure_trailing_slash_if_no_hierarchy('http://example.com/'))
    assert_equal('http://example.com/foo',
                 AuthWorld.ensure_trailing_slash_if_no_hierarchy('http://example.com/foo'))
    assert_equal('http://example.com/foo/',
                 AuthWorld.ensure_trailing_slash_if_no_hierarchy('http://example.com/foo/'))
    assert_equal('http://example.com/foo/bar',
                 AuthWorld.ensure_trailing_slash_if_no_hierarchy('http://example.com/foo/bar'))
    assert_equal('http://example.com/foo/bar/',
                 AuthWorld.ensure_trailing_slash_if_no_hierarchy('http://example.com/foo/bar/'))
  end

  def test_auth_table
    tbl = AuthTable.new

    tbl[@opts1] = @digest_auth
    assert_nil tbl[@opts2]
    
    tbl[@opts2] = @basic_auth

    assert_equal @digest_auth, tbl[@opts1]
    assert_equal @basic_auth,  tbl[@opts2]
  end

  def test_auth_table_ignore_irrelevant_options
    tbl = AuthTable.new
    
    tbl[@opts1.merge(:foo => :bar)] = @digest_auth
    assert_equal @digest_auth, tbl[@opts1]

    tbl[@opts2] = @basic_auth
    assert_equal @basic_auth, tbl[@opts2.merge(:bar => :foo)]
  end

  def test_auth_space
    space = AuthSpace.new 'http://example.com/'

    assert_equal 'http://example.com/', space.prefix

    space.update_auth @digest_auth, @opts1
    assert_equal @digest_auth, space.get_auth(:digest, @opts1)

    space.update_auth @basic_auth, @opts2
    assert_equal @digest_auth, space.get_auth(:digest, @opts1)
    assert_equal @basic_auth, space.get_auth(:basic, @opts2)

    assert_nil space.get_auth(:digest, @opts2)
    assert_nil space.get_auth(:basic, @opts1)

    assert_raises ArgumentError do
      space.update_auth @digest_auth, @opts1.merge(:realm => 'users@othersite.com')
    end
  end

  def test_auth_space_comparable

    space1 = AuthSpace.new 'http://example.com/'
    space2 = AuthSpace.new 'http://example.com/bar'

    space1.update_auth @digest_auth, @opts1
    space2.update_auth @basic_auth, @opts2

    assert space1 < space2

    space3 = AuthSpace.new 'http://example.com/'

    assert_equal space1, space3
    assert_not_same space1, space3
    assert_not_equal space2, space3
  end

   def test_auth_world
     world = AuthWorld.new
     
     world.add_auth @digest_auth, 'http://example.com/tim/index.html', @opts1
     world.add_auth @basic_auth, 'http://example.com/chetan/index.html', @opts2
     
     world.add_auth(@digest_auth_multiple_domains,
                    'http://limebits.com/home/paritosh/index.html', @opts3)
     world.add_auth @basic_auth, 'http://example.com/tim/index.html', @opts2
     
     world.add_auth(@digest_auth_separate_path_domains,
                    'http://limespot.com/home/jam/index.html', @opts4)

     assert_equal(@digest_auth,
                  world.get_auth('http://example.com/tim/index.html', @opts1))
     
     assert_equal(@basic_auth,
                  world.get_auth('http://example.com/chetan/index.html', @opts2))
     assert_equal(@basic_auth,
                  world.get_auth('http://example.com/tim/index.html', @opts2))
     
     assert_equal(@digest_auth_multiple_domains,
                  world.get_auth('http://limebits.com/home/paritosh/index.html', @opts3))

     assert_equal(@digest_auth_separate_path_domains,
                  world.get_auth('http://limespot.com/home/jam/index.html', @opts4))


     assert_equal(@digest_auth,
                  world.get_auth('http://example.com/chetan', @opts1))

     assert_equal(@basic_auth,
                  world.get_auth('http://example.com/chetan/foo', @opts2))
     assert_equal(@basic_auth,
                  world.get_auth('http://example.com/tim/foo', @opts2))
     
     assert_equal(@basic_auth,
                  world.get_auth('http://example.com/chetan/', @opts2))
     assert_equal(@basic_auth,
                  world.get_auth('http://example.com/tim/', @opts2))
     
     assert_nil world.get_auth('http://example.com/', @opts2)
     assert_nil world.get_auth('http://example.com/paritosh', @opts2)
     assert_nil world.get_auth('http://example.com/paritosh/', @opts2)

     assert_equal(@digest_auth_multiple_domains,
                  world.get_auth('https://limebits.com/foo', @opts3))
     assert_equal(@digest_auth_multiple_domains,
                  world.get_auth('http://paritosh.limebits.com/foo', @opts3))
     assert_nil world.get_auth('http://tim.limebits.com/', @opts3)

     assert_equal(@digest_auth_separate_path_domains,
                  world.get_auth('http://limespot.com/home/tim/foo', @opts4))

     assert_nil world.get_auth('http://limebits.com/home/jam/foo', @opts4)
     assert_nil world.get_auth('http://limebits.com/home/tim/foo', @opts4)
   end

  
end
