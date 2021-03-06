require 'test/unit/unit_test_helper'
require 'set'

class ResponseTest < Test::Unit::TestCase
  def setup
    @url = "www.example.org"
    @status = "200"
    @headers = {}
    @response = RubyDav::Response.create(@url, @status, @headers, "", :get)
  end
  
  def test_simple
    assert_instance_of RubyDav::Response, @response
  end
  
  def test_attributes
    assert_equal @url, @response.url
    assert_equal @status, @response.status
  end

  def test_headers
    headers = {"locktoken" => "random"}
    @response = RubyDav::Response.new(@url, @status, headers)
    assert_equal headers, @response.headers
  end

  def test_date
    headers = {"date" => [Time.now]}
    @response = RubyDav::Response.new(@url, @status, headers)
    assert_equal headers["date"][0], @response.date
  end

  def test_etag
    headers = {'etag' => ['fake_etag']}
    response = RubyDav::Response.new(@url, @status, headers)
    assert_equal 'fake_etag', response.etag
  end
  
  def test_etag__empty
    headers = {'etag' => []}
    response = RubyDav::Response.new(@url, @status, headers)
    assert_nil response.etag
  end
  
  def test_etag__multiple_etags
    headers = {'etag' => ['fake_etag1', 'fake_etag2']}
    response = RubyDav::Response.new(@url, @status, headers)
    assert_equal 'fake_etag1', response.etag
  end
  
  def test_etag__no_etag
    response = RubyDav::Response.new(@url, @status, {})
    assert_nil response.etag
  end
  
  def test_initialize
    response = RubyDav::Response.new(@url, @status, @headers)
    assert_equal @url, response.url
    assert_equal @status, response.status
    assert_equal @headers, response.headers
  end

end

class SuccessfulResponseTest < Test::Unit::TestCase
  def setup
    @response = RubyDav::SuccessfulResponse.create("www.example.org", "200", {},"",:get)
  end
  
  def test_simple
    assert_instance_of RubyDav::SuccessfulResponse, @response
  end
  
  def test_error
    assert !@response.error?
  end
end

class ErrorResponseTest < Test::Unit::TestCase
  def setup
    @response = RubyDav::ErrorResponse.create("www.example.org", "404", {}, "", :get)
  end

  def test_error
    assert @response.error?
  end
  
  def test_simple
    assert_instance_of RubyDav::ErrorResponse, @response
  end

  def test_xml_content_type__application_xml
    hdrs = { 'content-type' => [ 'bar', 'application/xml; charset=iso-8859-1' ] }
    assert RubyDav::ErrorResponse.xml_content_type?(hdrs)
  end
  
  def test_xml_content_type__image_svg_xml
    hdrs = { 'content-type' => [ 'image/svg+xml ' ] }
    assert RubyDav::ErrorResponse.xml_content_type?(hdrs)
  end
  
  def test_xml_content_type__not_xml
    hdrs = { 'content-type' => [ 'foo', 'bar' ] }
    assert !RubyDav::ErrorResponse.xml_content_type?(hdrs)
  end
  
  def test_xml_content_type__text_xml
    hdrs = { 'content-type' => [ 'text/xml', 'foo' ] }
    assert RubyDav::ErrorResponse.xml_content_type?(hdrs)
  end
  
end

class OkLockResponseTest < Test::Unit::TestCase
  def setup
    @body = <<EOS
<?xml version="1.0" encoding="utf-8" ?> 
<D:prop xmlns:D="DAV:"> 
  <D:lockdiscovery> 
    <D:activelock> 
      <D:locktype><D:write/></D:locktype> 
      <D:lockscope><D:exclusive/></D:lockscope> 
      <D:depth>infinity</D:depth> 
      <D:owner> 
        <D:href>http://example.org/~ejw/contact.html</D:href> 
      </D:owner> 
      <D:timeout>Second-604800</D:timeout> 
      <D:locktoken> 
        <D:href
        >urn:uuid:e71d4fae-5dec-22d6-fea5-00a0c91e6be4</D:href> 
      </D:locktoken> 
      <D:lockroot> 
        <D:href
        >http://example.com/workspace/webdav/proposal.doc</D:href> 
      </D:lockroot> 
    </D:activelock> 
  </D:lockdiscovery> 
</D:prop>
EOS
    @locktoken = 'urn:uuid:e71d4fae-5dec-22d6-fea5-00a0c91e6be4'

  end

  def test_create
    response = RubyDav::OkLockResponse.create('www.example.org', '200',
                                              { 'lock-token' =>
                                                ["<#{@locktoken}>"]},
                                              @body, :lock)
    assert_instance_of RubyDav::OkLockResponse, response
    assert_instance_of RubyDav::LockDiscovery, response.lock_discovery
    assert_equal 1, response.lock_discovery.locks.size
    assert_equal @locktoken, response.lock_token
    assert_equal [@locktoken], response.lock_discovery.locks.keys
    
    assert_equal 'http://example.com/workspace/webdav/proposal.doc', response.active_lock.root
  end

  def test_create__without_lock_token_header
    response = RubyDav::OkLockResponse.create('www.example.org', '200',
                                              {}, @body, :lock)
    assert_instance_of RubyDav::OkLockResponse, response
    assert_instance_of RubyDav::LockDiscovery, response.lock_discovery
    assert_equal 1, response.lock_discovery.locks.size
    assert_nil response.lock_token
    assert_equal [@locktoken], response.lock_discovery.locks.keys

    assert_nil response.active_lock
    assert_equal('http://example.com/workspace/webdav/proposal.doc',
                 response.lock_discovery.locks.values[0].root)
  end

  def test_initialize
    response = RubyDav::OkLockResponse.send(:new, 'www.example.org', '200',
                                            { 'lock-token' =>
                                              ["<#{@locktoken}>"]},
                                            @body, :lock_discovery)
    assert_instance_of RubyDav::OkLockResponse, response
    assert_equal :lock_discovery, response.lock_discovery
  end

  def test_initialize__multiple_lock_token_headers
    assert_raises RubyDav::BadResponseError do
      RubyDav::OkLockResponse.send(:new, 'www.example.org', '200',
                                   { 'lock-token' =>
                                     [ '<token1>', '<token2>' ]},
                                   @body, :lock_discovery)
    end
  end
  
  def test_parse_body
    lock_discovery = RubyDav::OkLockResponse.parse_body @body
    assert_instance_of RubyDav::LockDiscovery, lock_discovery
  end

  @@bad_bodies = {
    :prop => '<notprop/>',
    :lock_discovery =>
    "<D:prop xmlns:D='DAV:'><notlockdiscovery/></D:prop>",
  }

  @@bad_bodies.each do |k, v|
    define_method "test_parse_body__bad_#{k}" do
      assert_raises(RubyDav::BadResponseError) { RubyDav::OkLockResponse.parse_body v }
    end
  end

end

class OkResponseTest < Test::Unit::TestCase
  def setup
    @body = "test body"
    @response = RubyDav::OkResponse.create("www.example.org", "200", {}, @body, :get)
  end
  
  def test_simple
    assert_instance_of RubyDav::OkResponse, @response
  end
  
  def test_body
    assert_equal @body, @response.body
  end
end

class MultiStatusResponseTest < RubyDavUnitTestCase
  def setup
    statuslist = []
    statuslist << ["412",["http://www.example.org/othercontainer/R2/","http://www.example.org/othercontainer/R3/"]]
    statuslist << ["403",["http://www.example.org/othercontainer/R4/R5/"]]
    
    @url = "www.example.org/othercontainer"
    @description = "Copied with errors"
    @body = @@response_builder.construct_copy_response(statuslist,@description)
    @response = RubyDav::MultiStatusResponse.create(@url,"207",{},@body,:copy)
    @responses = @response.responses
  end
  
  def test_simple
    assert_instance_of RubyDav::MultiStatusResponse, @response
    assert @response.error?
  end
  
  def test_attributes
    assert_equal @description, @response.description
    assert_equal @url, @response.url
    assert_equal "207", @response.status
  end

  def test_responses
    prefix = 'http://www.example.org/othercontainer/'
    assert_equal 3, @responses.length

    %w(R2/ R3/ R4/R5/).each do |suffix|
      url = prefix + suffix
      assert_equal url, @responses[url].href
    end

    assert_equal '412', @responses[prefix + 'R2/'].status
    assert_equal '412', @responses[prefix + 'R3/'].status
    assert_equal '403', @responses[prefix + 'R4/R5/'].status
  end
  
  def test_initialize
    responses = @responses.clone
    response = RubyDav::MultiStatusResponse.new(@url, '207', {}, @body, responses, :copy, "description")
    
    assert_equal @url, response.url
    assert_equal '207', response.status
    assert_equal({}, response.headers)
    assert_equal @body, response.body
    assert_equal responses, response.responses
    assert_equal "description", response.description
  end
end

class MkcolResponseTest < RubyDavUnitTestCase
  def setup
    super
    @url = "http://www.example.org/othercontainer"
    @body = @@response_builder.construct_mkcol_response([["200", nil, [["resourcetype","DAV:",nil],["email","http://limebits.com/ns/1.0/",nil]]]])
    @fail_body = @@response_builder.construct_mkcol_response([["424", nil, [["resourcetype","DAV:",nil]]],["403", nil, [["email","http://limebits.com/ns/1.0/",nil]]]])
    @response = RubyDav::MkcolResponse.create(@url,"201",{},@body,:mkcol_ext)
    @bad_response = RubyDav::MkcolResponse.create(@url,"424",{},@fail_body,:mkcol_ext)
  end

  def test_parse_body
    response_str = <<EOS
<D:mkcol-response xmlns:D="DAV:">
  <D:propstat>
    <D:prop>
      <D:resourcetype/>
      <D:displayname/>
    </D:prop>
    <D:status>HTTP/1.1 200 OK</D:status>
  </D:propstat>
</D:mkcol-response> 
EOS

    root = body_root_element response_str
    resourcetype_prop = RubyDav.get_dav_descendent root, 'propstat', 'prop', 'resourcetype'
    displayname_prop = RubyDav.get_dav_descendent root, 'propstat', 'prop', 'displayname'

    expected = {
      '/home/special' => {
        @displayname_pk =>
        RubyDav::PropertyResult.new(@displayname_pk, '200', displayname_prop),
        @resourcetype_pk =>
        RubyDav::PropertyResult.new(@resourcetype_pk, '200', resourcetype_prop)
      }
    }
    
    actual =
      RubyDav::MkcolResponse.send :parse_body, response_str, '/home/special'

    assert_equal expected, actual
  end
    
  def test_parse_body__bad_root
    response_str = <<EOS
<D:foo-response xmlns:D="DAV:">
  <D:propstat>
    <D:prop>
      <D:resourcetype/>
      <D:displayname/>
    </D:prop>
    <D:status>HTTP/1.1 200 OK</D:status>
  </D:propstat>
</D:foo-response> 
EOS

    assert_raises RubyDav::BadResponseError do
      RubyDav::MkcolResponse.send :parse_body, response_str, '/home/special'
    end
  end
  
  def test_simple
    assert_instance_of RubyDav::MkcolResponse, @response
    assert_instance_of RubyDav::MkcolResponse, @bad_response
    assert_equal '201', @response.status
    assert @bad_response.error?
  end

end

class PropstatResponseTest < RubyDavUnitTestCase

  def assert_property_result prop, pk, result, status = '200', error = nil
    element = RubyDav.first_element_named prop, pk.name, pk.ns
    assert_equal pk, result.prop_key
    assert_equal status, result.status
    assert_equal error, result.error
    assert_equal element.to_s, result.element.to_s
  end

  def get_prop response, status = 'HTTP/1.1 200 OK'
    RubyDav.each_element_named response, 'propstat' do |propstat_elem|
      status_elem = RubyDav.first_element_named propstat_elem, 'status'
      return RubyDav.first_element_named(propstat_elem, 'prop') if
        status_elem.content == status
    end
  end

  def get_response root, url
    RubyDav.each_element_named root, 'response' do |response_elem|
      return response_elem if
        RubyDav.first_element_named(response_elem, 'href').content == url
    end
  end

  def get_results props
    results = {}
    props.each do |pk, prop|
      results[pk] = RubyDav::PropertyResult.new pk, '200', prop
    end
    return results
  end

  def expected_props prop_element, prop_keys
    return prop_keys.inject({}) do |h, k|
      h[k] = RubyDav.first_element_named prop_element, k.name, k.ns
      next h
    end
  end
  
  def setup
    super

    @propfind_response_str = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:multistatus xmlns:D="DAV:">
  <D:response>
    <D:href>/container/</D:href>
    <D:propstat>
      <D:prop xmlns:R="http://ns.example.com/boxschema/">
        <R:bigbox><R:BoxType>Box type A</R:BoxType></R:bigbox>
        <R:author><R:Name>Hadrian</R:Name></R:author>
        <D:creationdate>1997-12-01T17:42:21-08:00</D:creationdate>
        <D:displayname>Example collection</D:displayname>
        <D:resourcetype><D:collection/></D:resourcetype>
        <D:supportedlock>
          <D:lockentry>
            <D:lockscope><D:exclusive/></D:lockscope>
            <D:locktype><D:write/></D:locktype>
          </D:lockentry>
          <D:lockentry>
            <D:lockscope><D:shared/></D:lockscope>
            <D:locktype><D:write/></D:locktype>
          </D:lockentry>
        </D:supportedlock>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
  <D:response>
    <D:href>/container/front.html</D:href>
    <D:propstat>
      <D:prop xmlns:R="http://ns.example.com/boxschema/">
        <R:bigbox><R:BoxType>Box type B</R:BoxType>
        </R:bigbox>
        <D:creationdate>1997-12-01T18:27:21-08:00</D:creationdate>
        <D:displayname>Example HTML resource</D:displayname>
        <D:getcontentlength>4525</D:getcontentlength>
        <D:getcontenttype>text/html</D:getcontenttype>
        <D:getetag>"zzyzx"</D:getetag>
        <D:getlastmodified
          >Mon, 12 Jan 1998 09:25:56 GMT</D:getlastmodified>
        <D:resourcetype/>
        <D:supportedlock>
          <D:lockentry>
            <D:lockscope><D:exclusive/></D:lockscope>
            <D:locktype><D:write/></D:locktype>
          </D:lockentry>
          <D:lockentry>
            <D:lockscope><D:shared/></D:lockscope>
            <D:locktype><D:write/></D:locktype>
          </D:lockentry>
        </D:supportedlock>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>
EOS

    propfind_response_root = body_root_element @propfind_response_str
    @container_response = get_response propfind_response_root, '/container/'
    @front_response =
      get_response propfind_response_root, '/container/front.html'

    @container_prop = get_prop @container_response
    @front_prop = get_prop @front_response
    @props = {
      '/container/' => @container_prop,
      '/container/front.html' => @front_prop
    }

    @container_prop_keys =
      [
       RubyDav::PropKey.get('http://ns.example.com/boxschema/', 'bigbox'),
       RubyDav::PropKey.get('http://ns.example.com/boxschema/', 'author'),
       RubyDav::PropKey.get('DAV:', 'creationdate'),
       RubyDav::PropKey.get('DAV:', 'displayname'),
       RubyDav::PropKey.get('DAV:', 'resourcetype'),
       RubyDav::PropKey.get('DAV:', 'supportedlock')
      ]

    @front_prop_keys =
      [
       RubyDav::PropKey.get('http://ns.example.com/boxschema/', 'bigbox'),
       RubyDav::PropKey.get('DAV:', 'creationdate'),
       RubyDav::PropKey.get('DAV:', 'displayname'),
       RubyDav::PropKey.get('DAV:', 'getcontentlength'),
       RubyDav::PropKey.get('DAV:', 'getcontenttype'),
       RubyDav::PropKey.get('DAV:', 'getetag'),
       RubyDav::PropKey.get('DAV:', 'getlastmodified'),
       RubyDav::PropKey.get('DAV:', 'resourcetype'),
       RubyDav::PropKey.get('DAV:', 'supportedlock')
      ]


    @expected_container_props =
      expected_props @container_prop, @container_prop_keys
    @expected_front_props = expected_props @front_prop, @front_prop_keys

    @expected_container_results = get_results @expected_container_props
    @expected_front_results = get_results @expected_front_props

    @response =
      RubyDav::PropstatResponse.create('/container/', '207', {},
                                       @propfind_response_str, :propfind)
    @propfind2_response_str = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:multistatus xmlns:D="DAV:">
  <D:response>
    <D:href>/container2/</D:href>
    <D:propstat>
      <D:prop>
        <D:displayname>Example collection</D:displayname>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
    <D:propstat>
      <D:prop>
        <D:resourcetype/>
      </D:prop>
      <D:status>HTTP/1.1 401 Unauthorized</D:status>
    </D:propstat>
    <D:propstat>
      <D:prop>
        <D:supportedlock/>
      </D:prop>
      <D:status>HTTP/1.1 403 Forbidden</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>
EOS
    @propfind2_response_root = body_root_element @propfind2_response_str
    @container2_response =
      get_response @propfind2_response_root, '/container2/'
    @container2_200_prop = get_prop @container2_response
    @container2_401_prop = get_prop @container2_response, 'HTTP/1.1 401 Unauthorized'
    @container2_403_prop = get_prop @container2_response, 'HTTP/1.1 403 Forbidden'

    @supportedlock_pk = RubyDav::PropKey.get('DAV:', 'supportedlock')

    @response2 =
      RubyDav::PropstatResponse.create('/container2/', '207', {},
                                       @propfind2_response_str, :propfind)

    @propfind3_response_str = <<EOS
<?xml version="1.0" encoding="utf-8" ?> 
<D:multistatus xmlns:D="DAV:"> 
  <D:response> 
    <D:href>http://www.example.com/file</D:href> 
    <D:propstat> 
      <D:prop>
        <D:displayname>A File</D:displayname>
        <D:getcontentlength>555</D:getcontentlength>
      </D:prop> 
      <D:status>HTTP/1.1 200 OK</D:status> 
    </D:propstat> 
  </D:response> 
</D:multistatus>
EOS
    propfind3_response_root = body_root_element @propfind3_response_str
    file_response =
      get_response propfind3_response_root, 'http://www.example.com/file'
    file_prop = get_prop file_response
    file_prop_keys = [@displayname_pk, @getcontentlength_pk]
    expected_file_props = expected_props file_prop, file_prop_keys
    @expected_file_results = get_results expected_file_props
    @response3 =
      RubyDav::PropstatResponse.create('http://www.example.com/file', '207', {},
                                       @propfind3_response_str, :propfind)
  end

  # tests [] operator
  def test_brackets__prop_key_multiple_urls
    assert_raises(RuntimeError) { @response[@displayname_pk] }
  end

  def test_brackets__prop_key_single_url
    assert_equal(@expected_file_results[@displayname_pk],
                 @response3[@displayname_pk])
  end
  
  def test_brackets__symbol_single_url
    assert_equal(@expected_file_results[@displayname_pk],
                 @response3[:displayname])
  end
  
  def test_brackets__url
    assert_equal @expected_container_results, @response['/container/']
  end

  def test_brackets__url_extra_slash
    assert_equal @expected_front_results, @response['/container/front.html/']
  end
  
  def test_brackets__url_missing_slash
    assert_equal @expected_container_results, @response['/container']
  end
  

  def test_create
    assert_instance_of RubyDav::PropstatResponse, @response
    assert_instance_of Hash, @response.resources
  end

  def test_error
    assert !@response.error?
    assert @response2.error?
  end

  def test_parse_body
    urlhash = RubyDav::PropstatResponse.send(:parse_body,
                                             @propfind_response_str,
                                             '/container/')
    expected_urls = ['/container/', '/container/front.html'].sort
    assert_equal expected_urls, urlhash.keys.sort

    assert_equal @container_prop_keys.sort, urlhash['/container/'].keys.sort
    assert_equal @front_prop_keys.sort, urlhash['/container/front.html'].keys.sort

    urlhash.each do |url, props|
      props.each do |pk, result|
        assert_property_result @props[url], pk, result
      end
    end
  end

  def test_parse_body2
    urlhash = RubyDav::PropstatResponse.send(:parse_body,
                                             @propfind2_response_str,
                                             '/container2/')
    assert_equal ['/container2/'], urlhash.keys

    container2_results = urlhash['/container2/']

    expected_pks = [@displayname_pk, @resourcetype_pk, @supportedlock_pk].sort
    assert_equal expected_pks, container2_results.keys.sort

    assert_property_result(@container2_200_prop, @displayname_pk,
                           container2_results[@displayname_pk], '200')
    assert_property_result(@container2_401_prop, @resourcetype_pk,
                           container2_results[@resourcetype_pk], '401')
    assert_property_result(@container2_403_prop, @supportedlock_pk,
                           container2_results[@supportedlock_pk], '403')
  end
  
  def test_parse_propstats
    actual =
      RubyDav::PropstatResponse.send :parse_propstats, @container_response
    assert_equal @expected_container_results, actual

    # test hash defaulting of symbols
    assert_equal(@expected_container_results[@displayname_pk],
                 actual[:displayname])

    # test hash with missing entry
    assert_nil actual[:missing]
  end

  def test_parse_propstats2
    expected = {}
    [[@displayname_pk, '200', @container2_200_prop],
     [@resourcetype_pk, '401', @container2_401_prop],
     [@supportedlock_pk, '403', @container2_403_prop]].each do |arr|
      pk, status, prop_element = arr
      prop = RubyDav.first_element_named prop_element, pk.name, pk.ns
      expected[pk] = RubyDav::PropertyResult.new pk, status, prop
    end

    actual =
      RubyDav::PropstatResponse.send :parse_propstats, @container2_response
    assert_equal expected, actual
  end

  def test_unauthorized
    assert !@response.unauthorized?
    assert @response2.unauthorized?
  end
   
end
