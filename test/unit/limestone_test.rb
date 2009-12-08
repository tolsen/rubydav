require 'lib/limestone'
require 'test/unit/unit_test_helper'

require 'stringio'

class LimestoneTestCase < RubyDavUnitTestCase

  def setup
    super

    @bitmark_request_body = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:propfind xmlns:D="DAV:">
  <D:allprop/>
  <D:include>
    <D:owner/>
  </D:include>
</D:propfind>
EOS

    @bitmark_response_body = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:multistatus xmlns:D="DAV:" xmlns:bm="http://limebits.com/ns/bitmarks/1.0/">
  <D:response>
    <D:href>/bitmarks/abcde</D:href>
    <D:propstat>
      <D:prop>
        <D:displayname>abcde</D:displayname>
        <D:owner><D:href>http://limebits.com/users/tim</D:href></D:owner>
        <bm:tag>inadvertant</bm:tag>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
  <D:response>
    <D:href>/bitmarks/abcde/1</D:href>
    <D:propstat>
      <D:prop>
        <D:displayname>1</D:displayname>
        <D:owner><D:href>http://limebits.com/users/tim</D:href></D:owner>
        <bm:tag>yellow</bm:tag>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
  <D:response>
    <D:href>/bitmarks/abcde/3</D:href>
    <D:propstat>
      <D:prop>
        <D:owner><D:href>http://limebits.com/users/tim</D:href></D:owner>
        <bm:name>mybit</bm:name>
        <bm:description>my cool bit</bm:description>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
  <D:response>
    <D:href>/bitmarks/abcde/2</D:href>
    <D:propstat>
      <D:prop>
        <D:displayname>another bitmark</D:displayname>
        <D:owner><D:href>http://limebits.com/users/chetan</D:href></D:owner>
        <bm:tag>cool</bm:tag>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
    <D:propstat>
      <D:prop><bm:description/></D:prop>
      <D:status>HTTP/1.1 401 Unauthorized</D:status>
    </D:propstat>
  </D:response>
  <D:response>
    <D:href>/bitmarks/abcde/4</D:href>
    <D:propstat>
      <D:prop>
        <D:owner><D:href>http://limebits.com/users/chetan</D:href></D:owner>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
    <D:propstat>
      <D:prop><bm:private/></D:prop>
      <D:status>HTTP/1.1 401 Unauthorized</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>
EOS

    @expected_bitmarks =
      [ bmark('description', 'my cool bit', 'http://limebits.com/users/tim',
              '/bitmarks/abcde/3'),
        bmark('name', 'mybit', 'http://limebits.com/users/tim',
              '/bitmarks/abcde/3'),
        bmark('tag', 'cool', 'http://limebits.com/users/chetan',
              '/bitmarks/abcde/2'),
        bmark('tag', 'yellow', 'http://limebits.com/users/tim',
              '/bitmarks/abcde/1') ]

  end
end

class LimestoneTest < LimestoneTestCase

  def setup
    super
    @user_url = "#{@host}/users/timmay"
    @user_path = URI.parse(@user_url).path
  end

  def test_put_user
    mock_put_user_response
    response = RubyDav::Request.put_user(@user_url,
                                         :new_password => 'opensesame',
                                         :displayname => 'Timmay!',
                                         :email => 'timmay@example.com')

    assert_equal '201', response.status
  end

  def test_create_user
    mock_put_user_response do |req|
      assert_equal '*', req['If-None-Match']
    end

    response = RubyDav::Request.create_user(@user_url, 'opensesame', 'Timmay!',
                                            'timmay@example.com')

    assert_equal '201', response.status
  end

  def test_modify_user
    mock_put_user_response '204' do |req|
      assert_equal '*', req['If-Match']
    end
    
    response = RubyDav::Request.modify_user(@user_url,
                                            :new_password => 'opensesame',
                                            :displayname => 'Timmay!',
                                            :email => 'timmay@example.com')

    assert_equal '204', response.status
  end

  def test_propfind_bitmarks
    mresponse = mock_response 207, @bitmark_response_body

    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).with(on do |req|
                                           validate_propfind(req, 1,
                                                             @bitmark_request_body,
                                                             '/bitmarks/abcde')
                                         end).and_return(mresponse)
    end

    response = RubyDav::Request.new(:base_url => 'http://www.example.com/').
      propfind_bitmarks('ab-cd-e')

    assert_instance_of RubyDav::BitmarkResponse, response
    assert_equal '207', response.status
    assert_equal @expected_bitmarks, response.bitmarks.sort
  end

  def test_propfind_bitmarks__not_found
    mresponse = mock_response 404

    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).with(on do |req|
                                           validate_propfind(req, 1,
                                                             @bitmark_request_body,
                                                             '/bitmarks/abcde')
                                         end).and_return(mresponse)
    end

    response = RubyDav::Request.new(:base_url => 'http://www.example.com/').
      propfind_bitmarks('ab-cd-e')

    assert_instance_of RubyDav::NotFoundError, response
    assert_equal '404', response.status
  end

  def mock_put_user_response response = '201', &block
    flexstub(Net::HTTP).new_instances do |http|
      mresponse = mock_response(response)

      validate_put_user = lambda do |req|

        assert_instance_of Net::HTTP::Put, req
        assert_equal @user_path, req.path
        yield req if block_given?
        
        assert_xml_matches req.body_stream.read do |xml|
          xml.xmlns! 'http://limebits.com/ns/1.0/'
          xml.xmlns! :D => 'DAV:'
          xml.user do
            xml.password 'opensesame'
            xml.D :displayname, 'Timmay!'
            xml.email 'timmay@example.com'
          end
        end
      end
      
      http.should_receive(:request).with(on(&validate_put_user)).and_return(mresponse)
        
    end

  end
  

end

class BitmarkResponseTest < LimestoneTestCase

  def assert_create response_body, expected_bitmarks
    br = RubyDav::BitmarkResponse.create('/bitmarks/abcde', '207', {},
                                         response_body, :propfind)
    assert_equal expected_bitmarks, br.bitmarks.sort
  end

  def test_create
    assert_create @bitmark_response_body, @expected_bitmarks
  end

  def test_create__no_bitmarks
    response = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:multistatus xmlns:D="DAV:" xmlns:bm="http://limebits.com/ns/bitmarks/1.0/">
  <D:response>
    <D:href>/bitmarks/abcde</D:href>
    <D:propstat>
      <D:prop>
        <D:displayname>abcde</D:displayname>
        <D:owner><D:href>http://limebits.com/users/tim</D:href></D:owner>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>
EOS
    assert_create response, []
  end

end
