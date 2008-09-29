require 'test/unit/unit_test_helper'

require 'digest/md5'
require 'httpauth/digest'

class RequestAuthTest < RubyDavUnitTestCase

  def setup
    super
    @body = "test body"
    @resp200 = mock_response("200", @body)

    @valid_unauth_get = on do |req|
      validate_get(req) && req['Authorization'].nil?
    end

    @realm = 'users@limebits.com'
    @nonces = {}

    @unauth_request_count = 0
    @auth_request_count = 0

  end

  def test_basic_auth
    resp401 = mock_response("401", nil,
                            'WWW-Authenticate' => 'Basic realm="users@limebits.com"')


    valid_auth_get = on do |req|
      validate_get(req) && (req['Authorization'] == 'Basic dGltOnN3b3JkZmlzaA==')
    end
    
    flexmock(Net::HTTP).new_instances do |http|
      http.should_receive(:request).once.with(@valid_unauth_get).and_return(resp401).ordered
      http.should_receive(:request).at_most.once.with(valid_auth_get).and_return(@resp200).ordered
    end

    request = RubyDav::Request.new :username => 'tim', :password => 'swordfish'
    assert_raise(SecurityError) { request.get @host }


    request = RubyDav::Request.new(:username => 'tim',
                                   :password => 'swordfish',
                                   :force_basic_auth => true)
    
    assert_nothing_raised(SecurityError) do
      assert_valid_response request.get(@host)
    end
  end

  def test_basic_auth_basic_creds
    resp401 = mock_response("401", nil,
                            'WWW-Authenticate' => 'Basic realm="users@limebits.com"')

    valid_auth_get = on do |req|
      validate_get(req) && (req['Authorization'] == 'Basic dGltOnN3b3JkZmlzaA==')
    end
    
    flexmock(Net::HTTP).new_instances do |http|
      http.should_receive(:request).once.with(@valid_unauth_get).and_return(resp401).ordered
      http.should_receive(:request).once.with(valid_auth_get).and_return(@resp200).ordered
    end

    request = RubyDav::Request.new(:basic_creds => 'dGltOnN3b3JkZmlzaA==',
                                   :force_basic_auth => true)
    
    assert_valid_response request.get(@host)
  end

  def test_digest_auth
    request = RubyDav::Request.new :username => 'tim', :password => 'swordfish'

    valid_auth_get = valid_digest_get 'tim', 'swordfish'

    flexmock(Net::HTTP).new_instances do |http|
      add_unauth_expectation http
      add_auth_expectation http, valid_auth_get, 'tim', 'swordfish'
      add_auth_expectation http, valid_auth_get, 'tim', 'swordfish', 'new body'
    end

    assert_valid_response request.get(@host)
    assert_valid_response request.get(@host), 'new body'

    assert_equal 1, @unauth_request_count
    assert_equal 2, @auth_request_count
  end

  def test_digest_auth_session_file
    tmp_path = generate_tmpfile_path
    
    request = RubyDav::Request.new(:username => 'tim', :password => 'swordfish',
                                   :digest_session => tmp_path)
    
    assert_receives_401_and_then_200 'tim', 'swordfish', request

    request = nil
    request = RubyDav::Request.new(:username => 'tim', :password => 'swordfish',
                                   :digest_session => tmp_path)
    @body = "new body"
    assert_receives_200 'tim', 'swordfish', request, false, "new body"
  end

  def test_digest_auth_multiple_www_authenticate_lines
    assert_correct_response_given_multiple_www_authenticate_headers do
      r = mock_response "401"
      r.add_field 'WWW-Authenticate', 'Basic realm="users@limebits.com"'
      r.add_field 'WWW-Authenticate', 'Basic realm="foo@othersite.com"'
      r.add_field 'WWW-Authenticate', HTTPAuth::Digest::Challenge.new(:realm => @realm).to_header
      r.add_field 'WWW-Authenticate', 'Basic realm="bar@yetanothersite.com"'
      r.add_field 'WWW-Authenticate', HTTPAuth::Digest::Challenge.new(:realm => 'users@somethingelse.com').to_header
      r
    end
    
  end

  def test_digest_auth_multiple_www_authenticate_lines2
    assert_correct_response_given_multiple_www_authenticate_headers do
      r = mock_response "401"
      r.add_field 'WWW-Authenticate', HTTPAuth::Digest::Challenge.new(:realm => @realm).to_header
      r.add_field 'WWW-Authenticate', 'Basic realm="users@limebits.com"'
      r.add_field 'WWW-Authenticate', 'Basic realm="foo@othersite.com"'
      r.add_field 'WWW-Authenticate', 'Basic realm="bar@yetanothersite.com"'
      r.add_field 'WWW-Authenticate', HTTPAuth::Digest::Challenge.new(:realm => 'users@somethingelse.com').to_header
      r
    end
    
  end

  def test_digest_auth_multiple_www_authenticate_lines3
    assert_correct_response_given_multiple_www_authenticate_headers(@realm) do
      r = mock_response "401"
      r.add_field 'WWW-Authenticate', HTTPAuth::Digest::Challenge.new(:realm => 'users@somethingelse.com').to_header
      r.add_field 'WWW-Authenticate', 'Basic realm="users@limebits.com"'
      r.add_field 'WWW-Authenticate', 'Basic realm="foo@othersite.com"'
      r.add_field 'WWW-Authenticate', 'Basic realm="bar@yetanothersite.com"'
      r.add_field 'WWW-Authenticate', HTTPAuth::Digest::Challenge.new(:realm => @realm).to_header
      r
    end
    
  end

  def test_digest_auth_using_digest_a1
    h_a1 = Digest::MD5::hexdigest 'tim:users@limebits.com:swordfish'
    request = RubyDav::Request.new :username => 'tim', :digest_a1 => h_a1
    assert_receives_401_and_then_200 'tim', 'swordfish', request
  end

  def test_request_rooturl
    valid_get = on do |req|
      req.is_a?(Net::HTTP::Get) &&
        (req.path == "/limespot/foo")
    end
    
    flexmock(Net::HTTP).new_instances do |http|
      http.should_receive(:request).once.with(valid_get).and_return(@resp200)
    end
    
    request = RubyDav::Request.new :base_url => "http://www.example.com/limespot/"
    assert_valid_response request.get('foo')
  end

  def test_request_returns_second_401
    request = RubyDav::Request.new :username => 'tim', :password => 'swordfish'

    flexmock(Net::HTTP).new_instances do |http|
      add_unauth_expectation http
      add_auth_expectation_returning_401 http, valid_digest_get
      http.should_receive(:request).zero_or_more_times.ordered.and_return { flunk "too many requests made!" }
    end

    response = request.get @host
    assert_equal '401', response.status
  end

  def test_request_retries_stale_second_401
    request = RubyDav::Request.new :username => 'tim', :password => 'swordfish'

    flexmock(Net::HTTP).new_instances do |http|
      add_unauth_expectation http
      add_auth_expectation_returning_401(http, valid_digest_get, 'tim', 'swordfish',
                                         @body, :default, true)
      add_auth_expectation http, valid_digest_get
      http.should_receive(:request).zero_or_more_times.ordered.and_return { flunk "too many requests made!" }
    end

    response = request.get @host
    assert_equal '200', response.status
  end

  def valid_ren_get() valid_digest_get 'ren', 'renpw'; end
  def valid_stimpy_get() valid_digest_get 'stimpy', 'stimpypw'; end
  
  def add_ren_expectation http
    add_auth_expectation http, valid_ren_get, 'ren', 'renpw', @body, :ren
  end
  
  def add_stimpy_expectation http
    add_auth_expectation http, valid_stimpy_get, 'stimpy', 'stimpypw', @body, :stimpy
  end
  
  def test_request_auth_override
    request = RubyDav::Request.new :username => 'ren', :password => 'renpw'

    flexmock(Net::HTTP).new_instances do |http|
      add_unauth_expectation http, :ren
      add_ren_expectation http
      add_unauth_expectation http, :stimpy
      add_stimpy_expectation http
      add_ren_expectation http
      add_stimpy_expectation http
    end

    assert_valid_response request.get(@host)
    assert_valid_response request.get(@host, :username => 'stimpy', :password => 'stimpypw')
    assert_valid_response request.get(@host)
    assert_valid_response request.get(@host, :username => 'stimpy', :password => 'stimpypw')

    assert_equal 2, @unauth_request_count
    assert_equal 4, @auth_request_count
  end

  def assert_valid_response response, body = @body, status = "200"
    assert_equal status, response.status
    assert_equal body, response.body
  end
  

  def valid_digest_get(username = 'tim', password = 'swordfish', nonce_key = :default)
    on do |req|
      validate_get(req) &&
        !(auth_hdr = req['Authorization']).nil? &&
        (@creds = HTTPAuth::Digest::Credentials.from_header req['Authorization']) &&
        @creds.h[:nonce] == @nonces[nonce_key] &&
        @creds.h[:username] == username &&
        @creds.h[:realm] == @realm
      @creds.validate_password(password, :method => 'GET')
    end
  end
  

  def assert_receives_401_and_then_200(username = 'tim', password = 'swordfish',
                                       request = nil, override = false, body = @body)
    @unauth_request_count = 0
    @auth_request_count = 0
    
    assert_receives_200_with_possible_401_first(true, username, password,
                                                request, override, body)

    assert_equal 1, @unauth_request_count
    assert_equal 1, @auth_request_count
  end

  def assert_receives_200(username = 'tim', password = 'swordfish',
                          request = nil, override = false, body = @body)
    @unauth_request_count = 0
    @auth_request_count = 0
    
    assert_receives_200_with_possible_401_first(false, username, password,
                                                request, override, body)
    
    assert_equal 0, @unauth_request_count
    assert_equal 1, @auth_request_count
  end

  def assert_receives_200_with_possible_401_first(expect401, username, password, request, override, body)
    valid_auth_get = valid_digest_get username, password

    Net::HTTP.flexmock_teardown if @last_http

    @last_http = flexmock(Net::HTTP).new_instances do |http|
      add_unauth_expectation http if expect401
      add_auth_expectation http, valid_auth_get, username, password
    end

    request = RubyDav::Request.new(:username => username, :password => password) if request.nil?
    opts = override ? { :username => username, :password => password } : {}
    assert_valid_response request.get(@host, opts), body
  end

  def add_unauth_expectation(http, nonce_key = :default)
    http.should_receive(:request).once.ordered.with(@valid_unauth_get).and_return do |req|
      @unauth_request_count += 1
      challenge = HTTPAuth::Digest::Challenge.new :realm => @realm
      r = mock_response "401", nil, 'WWW-Authenticate' => challenge.to_header
      @nonces[nonce_key] = challenge.h[:nonce]
      r
    end
  end

  def add_auth_expectation(http, valid_get, username = 'tim',
                           password = 'swordfish', body = @body, nonce_key = :default)
    http.should_receive(:request).once.ordered.with(valid_get).and_return do |req|
      @auth_request_count += 1
      auth_info = HTTPAuth::Digest::AuthenticationInfo.from_credentials(@creds,
                                                                        :username => username,
                                                                        :password => password,
                                                                        :realm => @realm)
      @nonces[nonce_key] = auth_info.h[:nextnonce]
      mock_response("200", body, 'Authentication-Info' => auth_info.to_header)
    end
  end

  def add_auth_expectation_returning_401(http, valid_get, username = 'tim',
                                         password = 'swordfish', body = @body,
                                         nonce_key = :default, stale = false)
    http.should_receive(:request).once.ordered.with(valid_get).and_return do |req|
      @auth_request_count += 1

      challenge = HTTPAuth::Digest::Challenge.new :realm => @realm, :stale => stale
      r = mock_response "401", nil, 'WWW-Authenticate' => challenge.to_header
      @nonces[nonce_key] = challenge.h[:nonce]
      r
    end
  end
  
  
  def assert_correct_response_given_multiple_www_authenticate_headers realm = nil, &block
    flexmock(Net::HTTP).new_instances do |http|
      http.should_receive(:request).once.ordered.with(@valid_unauth_get).and_return do |req|
        yield
      end

      http.should_receive(:request).once.ordered.with(valid_digest_get).and_return(mock_response("200", @body))
    end

    request = RubyDav::Request.new :username => 'tim', :password => 'swordfish', :realm => realm
    assert_valid_response request.get(@host)
  end
  
end
