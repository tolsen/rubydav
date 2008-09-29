require 'digest/md5'

require 'test/unit/unit_test_helper'

class DigestAuthTestCase < RubyDavUnitTestCase

  include RubyDav

  def setup
    @digest_auth = Auth.construct 'Digest realm="users@limespot.com", nonce="wPloasE7BAA=aa990a469b2526e74bf52add00efb83d96a17a56", algorithm=MD5, qop="auth", domain="http://limespot.com/ http://www.limespot.com/"'
    @username = 'ren'
    @password = 'renren'
    @a1 = "#{@username}:users@limespot.com:#{@password}"
    @h_a1 = Digest::MD5::hexdigest @a1
  end 
  
  def test_construct_digest_auth
    assert_instance_of DigestAuth, @digest_auth
    assert_equal 'users@limespot.com', @digest_auth.realm
    assert_equal :digest, @digest_auth.scheme
    assert_equal(["http://limespot.com/", "http://www.limespot.com/"], @digest_auth.domain)
  end

  def test_digest_authorization_missing_username
    assert_raises(RuntimeError) { @digest_auth.authorization 'GET', '/limespot/ren/timmay.gif' }
  end

  def test_digest_authorization_only_username_set
    @digest_auth.username = @username
    assert_raises(RuntimeError) { @digest_auth.authorization 'GET', '/limespot/ren/timmay.gif' }
  end

  def test_digest_authorization_using_password
    @digest_auth.username = @username
    @digest_auth.password = @password
    assert_valid_authorization
  end

  def test_digest_authorization_using_h_a1
    @digest_auth.username = @username
    @digest_auth.h_a1 = @h_a1
    assert_valid_authorization
  end

  def test_digest_authorization_nc_increases
    @digest_auth.username = @username
    @digest_auth.password = @password
    creds = HTTPAuth::Digest::Credentials.from_header @digest_auth.authorization('GET', '/limespot/ren')
    assert_equal 1, creds.h[:nc]
    creds = HTTPAuth::Digest::Credentials.from_header @digest_auth.authorization('GET', '/limespot/ren')
    assert_equal 2, creds.h[:nc]
  end

  def test_digest_auth_info
    @digest_auth.username = @username
    @digest_auth.password = @password
    assert_valid_auth_info
  end

  

  def test_digest_auth_info_invalid
    @digest_auth.username = @username
    @digest_auth.password = @password
    creds = HTTPAuth::Digest::Credentials.from_header @digest_auth.authorization('GET', '/limespot/ren')
    cnonce = creds.h[:cnonce]
#    _rspauth = rspauth creds.h[:nonce], "00000001", cnonce, '/limespot/ren'
    assert !@digest_auth.validate_auth_info("rspauth=\"FOOBAR\"," +
                                           "cnonce=\"#{cnonce}\"," +
                                           "nc=00000001,qop=auth")

  end

  def test_digest_auth_info_marshal
    @digest_auth.username = @username
    @digest_auth.password = @password

    filename = generate_tmpfile_path
    assert_valid_auth_info { dump_and_load_session filename }
  end

  def dump_and_load_session filename
    @digest_auth.dump_sans_creds filename
    @digest_auth = nil
    @digest_auth = DigestAuth.load filename

    assert_nil @digest_auth.username
    assert_nil @digest_auth.password

    @digest_auth.username = @username
    @digest_auth.password = @password
  end
  
  
  def assert_valid_authorization
    creds = HTTPAuth::Digest::Credentials.from_header @digest_auth.authorization('GET', '/limespot/ren')

    assert creds.validate_password(@password, :method => 'GET')
    assert creds.validate_digest(@h_a1, :method => 'GET')
    assert_equal '/limespot/ren', creds.h[:uri]
  end

  def assert_valid_auth_info &block
    creds = HTTPAuth::Digest::Credentials.from_header @digest_auth.authorization('GET', '/limespot/ren')
    cnonce = creds.h[:cnonce]
    _rspauth = rspauth creds.h[:nonce], "00000001", cnonce, '/limespot/ren'
    assert @digest_auth.validate_auth_info("rspauth=\"#{_rspauth}\"," +
                                           "cnonce=\"#{cnonce}\"," +
                                           "nc=00000001,qop=auth")

    yield if block_given?
    
    creds = HTTPAuth::Digest::Credentials.from_header @digest_auth.authorization('GET', '/limespot/ren')
    assert_equal 2, creds.h[:nc]
    assert_equal cnonce, creds.h[:cnonce]
    _rspauth = rspauth creds.h[:nonce], "00000002", cnonce, '/limespot/ren'
    nextnonce = HTTPAuth::Digest::Utils.create_nonce("pepper")
    assert @digest_auth.validate_auth_info("nextnonce=\"#{nextnonce}\"," +
                                           "rspauth=\"#{_rspauth}\"," +
                                           "cnonce=\"#{cnonce}\"," +
                                           "nc=00000002,qop=auth")

    yield if block_given?
    
    creds = HTTPAuth::Digest::Credentials.from_header @digest_auth.authorization('GET', '/limespot/ren')
    assert_equal nextnonce, creds.h[:nonce]
    assert_equal 1, creds.h[:nc]
    assert_equal cnonce, creds.h[:cnonce]
    _rspauth = rspauth nextnonce, "00000001", cnonce, '/limespot/ren'
    assert @digest_auth.validate_auth_info("rspauth=\"#{_rspauth}\"," +
                                           "cnonce=\"#{cnonce}\"," +
                                           "nc=00000001,qop=auth")
  end
  
  def rspauth nonce, nc, cnonce, uri
    h_a2 = response_h_a2 uri
    Digest::MD5.hexdigest "#{@h_a1}:#{nonce}:#{nc}:#{cnonce}:auth:#{h_a2}"
  end

  def response_h_a2 uri
    Digest::MD5.hexdigest ":#{uri}"
  end
  

end
